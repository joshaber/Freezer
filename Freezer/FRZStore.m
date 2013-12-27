//
//  FRZStore.m
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZStore.h"
#import "FRZStore+Private.h"
#import "FRZDatabase+Private.h"
#import "FRZTransactor+Private.h"
#import "FMDatabase.h"
#import "FRZChange.h"
#import "FRZChange+Private.h"
#import <pthread.h>

NSString * const FRZErrorDomain = @"FRZErrorDomain";

const NSInteger FRZErrorInvalidAttribute = -1;
const NSInteger FRZErrorInvalidValue = -2;

NSString * const FRZStoreHeadTransactionAttribute = @"Freezer/tx/head";
NSString * const FRZStoreTransactionDateAttribute = @"Freezer/tx/date";

NSString * const FRZStoreAttributeTypeAttribute = @"Freezer/attribute/type";
NSString * const FRZStoreAttributeIsCollectionAttribute = @"Freezer/attribute/is-collection";

@interface FRZStore ()

@property (nonatomic, readonly, strong) RACSubject *changesSubject;

@property (nonatomic, readonly, copy) NSString *databasePath;

@property (nonatomic, readonly, assign) pthread_key_t activeTransactionCountKey;

@property (nonatomic, readonly, assign) pthread_key_t queuedChangesKey;

@property (nonatomic, readonly, assign) pthread_key_t currentDatabaseKey;

@property (nonatomic, readonly, assign) pthread_key_t previousDatabaseKey;

@property (nonatomic, readonly, assign) pthread_key_t txIDKey;

@end

@implementation FRZStore

#pragma mark Lifecycle

- (void)dealloc {
	[_changesSubject sendCompleted];

	pthread_key_delete(_activeTransactionCountKey);
	pthread_key_delete(_queuedChangesKey);
	pthread_key_delete(_currentDatabaseKey);
	pthread_key_delete(_previousDatabaseKey);
	pthread_key_delete(_txIDKey);
}

- (id)initWithPath:(NSString *)path error:(NSError **)error {
	NSParameterAssert(path != nil);

	self = [super init];
	if (self == nil) return nil;

	_databasePath = [path copy];

	// Preflight the database so we get fatal errors earlier.
	FMDatabase *database = [self createDatabase:error];
	if (database == nil) return nil;

	_changesSubject = [RACSubject subject];

	pthread_key_create(&_activeTransactionCountKey, FRZStoreMallocDestructor);
	pthread_key_create(&_queuedChangesKey, FRZStoreReleaseDestructor);
	pthread_key_create(&_currentDatabaseKey, FRZStoreReleaseDestructor);
	pthread_key_create(&_previousDatabaseKey, FRZStoreReleaseDestructor);
	pthread_key_create(&_txIDKey, FRZStoreMallocDestructor);

	return self;
}

void FRZStoreMallocDestructor(void *data) {
	free(data);
}

void FRZStoreReleaseDestructor(void *data) {
	CFRelease(data);
}

- (id)initInMemory:(NSError **)error {
	// We need to name our in-memory DB so that we can open multiple connections
	// to it.
	NSString *name = [NSString stringWithFormat:@"file:%@?mode=memory&cache=shared", [[NSUUID UUID] UUIDString]];
	return [self initWithPath:name error:error];
}

- (id)initWithURL:(NSURL *)URL error:(NSError **)error {
	NSParameterAssert(URL != nil);

	return [self initWithPath:URL.path error:error];
}

- (FMDatabase *)createDatabase:(NSError **)error {
	FMDatabase *database = [FMDatabase databaseWithPath:self.databasePath];
	// No mutex, no cry.
	BOOL success = [database openWithFlags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_PRIVATECACHE];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return nil;
	}

	database.logsErrors = NO;

	return database;
}

- (BOOL)configureDatabase:(FMDatabase *)database error:(NSError **)error {
	NSParameterAssert(database != nil);

	database.shouldCacheStatements = YES;

	BOOL success = [database executeUpdate:@"PRAGMA legacy_file_format = 0;"];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	success = [database executeUpdate:@"PRAGMA synchronous = NORMAL;"];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	// Write-ahead logging is usually faster and offers better concurrency.
	//
	// Note that we're using -executeQuery: here, instead of -executeUpdate: The
	// result of turning on WAL is a row, which really rustles FMDB's jimmies if
	// done from -executeUpdate. So we pacify it by setting WAL in a "query."
	FMResultSet *set = [database executeQuery:@"PRAGMA journal_mode = WAL;"];
	if (set == nil) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	success = [self createTable:database error:error];
	if (!success) return NO;

	success = [self createIndexes:database error:error];
	if (!success) return NO;

	return YES;
}

- (BOOL)createTable:(FMDatabase *)database error:(NSError **)error {
	NSString *schema =
		@"CREATE TABLE IF NOT EXISTS data("
		"id INTEGER PRIMARY KEY AUTOINCREMENT,"
		"key STRING NOT NULL,"
		"attribute STRING NOT NULL,"
		"value BLOB,"
		"tx_id INTEGER NOT NULL"
	");";

	BOOL success = [database executeUpdate:schema];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	return YES;
}

- (BOOL)createIndexes:(FMDatabase *)database error:(NSError **)error {
	NSString *index = @"CREATE INDEX IF NOT EXISTS lookup_index ON data (key, attribute, tx_id)";
	BOOL success = [database executeUpdate:index];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	return YES;
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> %@", self.class, self, self.databasePath];
}

#pragma mark Properties

- (long long int)headID {
	// NB: This can't go through the standard FRZDatabase method of retrieval
	// because that needs to call -headID to fix the FRZDatabase to the current
	// head. :cry:
	FMDatabase *database = [self databaseForCurrentThread:NULL];
	if (database == nil) return -1;

	FMResultSet *set = [database executeQuery:@"SELECT value FROM data WHERE key = 'head' ORDER BY id DESC LIMIT 1"];
	if (set == nil) return -1;
	if (![set next]) return -1;

	NSData *data = [set objectForColumnIndex:0];
	NSNumber *ID = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	return ID.longLongValue;
}

- (FRZDatabase *)currentDatabase {
	long long int headID = [self headID];
	if (headID < 0) return nil;

	return [[FRZDatabase alloc] initWithStore:self headID:headID];
}

- (FMDatabase *)databaseForCurrentThread:(NSError **)error {
	FMDatabase *database = (__bridge id)pthread_getspecific(self.currentDatabaseKey);
	if (database == nil) {
		database = [self createDatabase:error];
		if (database == nil) return nil;

		pthread_setspecific(self.currentDatabaseKey, CFBridgingRetain(database));

		BOOL success = [self configureDatabase:database error:error];
		if (!success) return nil;

		return database;
	}

	return database;
}

- (FRZTransactor *)transactor {
	return [[FRZTransactor alloc] initWithStore:self];
}

- (NSMutableArray *)queuedChanges {
	NSMutableArray *array = (__bridge id)pthread_getspecific(self.queuedChangesKey);
	if (array != nil) return array;

	array = [NSMutableArray array];
	pthread_setspecific(self.queuedChangesKey, CFBridgingRetain(array));
	return array;
}

- (RACSignal *)changes {
	return self.changesSubject;
}

#pragma mark Transactions

- (NSUInteger)incrementTransactionCount {
	NSUInteger *transactionCount = pthread_getspecific(self.activeTransactionCountKey);
	if (transactionCount == NULL) {
		transactionCount = calloc(1, sizeof(*transactionCount));
		pthread_setspecific(self.activeTransactionCountKey, transactionCount);
	}

	*transactionCount = *transactionCount + 1;
	return *transactionCount;
}

- (NSUInteger)decrementTransactionCount {
	NSUInteger *transactionCount = pthread_getspecific(self.activeTransactionCountKey);
	NSAssert(transactionCount != NULL, @"Transaction count decrement without an increment. Not cool bro.");

	*transactionCount = *transactionCount - 1;
	return *transactionCount;
}

- (BOOL)performReadTransactionWithError:(NSError **)error block:(BOOL (^)(FMDatabase *database, NSError **error))block {
	NSParameterAssert(block != NULL);

	return [self performTransactionType:FRZStoreTransactionTypeDeferred withNewTransaction:NO error:error block:^(FMDatabase *database, long long txID, NSError **error) {
		return block(database, error);
	}];
}

- (BOOL)performWriteTransactionWithError:(NSError **)error block:(BOOL (^)(FMDatabase *database, long long int txID, NSError **error))block {
	NSParameterAssert(block != nil);

	return [self performTransactionType:FRZStoreTransactionTypeExclusive withNewTransaction:YES error:error block:block];
}

- (BOOL)performTransactionType:(FRZStoreTransactionType)transactionType withNewTransaction:(BOOL)withNewTransaction error:(NSError **)error block:(BOOL (^)(FMDatabase *database, long long int txID, NSError **error))block {
	NSParameterAssert(block != NULL);

	FMDatabase *database = [self databaseForCurrentThread:error];
	if (database == nil) return NO;

	long long int txID = -1;
	NSUInteger transactionCount = [self incrementTransactionCount];
	if (transactionCount == 1) {
		NSDictionary *transactionTypeToName = @{
			@(FRZStoreTransactionTypeDeferred): @"deferred",
			@(FRZStoreTransactionTypeExclusive): @"exclusive",
		};

		NSString *transactionTypeName = transactionTypeToName[@(transactionType)];
		NSAssert(transactionTypeName != nil, @"Unrecognized transaction type: %ld", transactionType);
		[database executeUpdate:[NSString stringWithFormat:@"begin %@ transaction", transactionTypeName]];

		FRZDatabase *previousDatabase = [self currentDatabase];
		if (previousDatabase != nil) {
			pthread_setspecific(self.previousDatabaseKey, CFBridgingRetain(previousDatabase));
		}

		if (withNewTransaction) {
			txID = [[self transactor] insertNewTransactionIntoDatabase:database error:error];
			if (txID < 0) return NO;

			long long int *txIDPerm = malloc(sizeof(*txIDPerm));
			*txIDPerm = txID;
			pthread_setspecific(self.txIDKey, txIDPerm);
		}
	} else {
		if (withNewTransaction) {
			long long int *txIDPerm = pthread_getspecific(self.txIDKey);
			NSAssert(txIDPerm != NULL, @"In a transaction but no txID in the thread. No cool bro.");
			txID = *txIDPerm;
		}
	}

	BOOL success = block(database, txID, error);
	transactionCount = [self decrementTransactionCount];

	BOOL cleanUp = NO;
	if (!success) {
		[database rollback];
		cleanUp = YES;
	} else {
		if (transactionCount == 0) {
			if (txID >= 0) {
				BOOL success = [[self transactor] updateHeadInDatabase:database toID:txID error:error];
				if (!success) return NO;
			}

			FRZDatabase *changedDatabase = [self currentDatabase];

			[database commit];

			FRZDatabase *previousDatabase = self.databaseBeforeTransaction;
			NSArray *queuedChanges = [self.queuedChanges copy];
			[self.queuedChanges removeAllObjects];
			for (FRZChange *change in queuedChanges) {
				change.previousDatabase = previousDatabase;
				change.changedDatabase = changedDatabase;
				[self.changesSubject sendNext:change];
			}

			cleanUp = YES;
		}
	}

	if (cleanUp) {
		long long int *txIDPerm = pthread_getspecific(self.txIDKey);
		pthread_setspecific(self.txIDKey, NULL);
		free(txIDPerm);

		void *database = pthread_getspecific(self.previousDatabaseKey);
		pthread_setspecific(self.previousDatabaseKey, NULL);
		if (database != NULL) CFRelease(database);
	}

	return success;
}

- (FRZDatabase *)databaseBeforeTransaction {
	return (__bridge id)pthread_getspecific(self.previousDatabaseKey);
}

@end
