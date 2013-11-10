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

@interface FRZStore ()

@property (nonatomic, readonly, strong) RACSubject *changesSubject;

@property (nonatomic, readonly, copy) NSString *databasePath;

@property (nonatomic, readonly, assign) pthread_key_t activeTransactionCountKey;

@property (nonatomic, readonly, assign) pthread_key_t queuedChangesKey;

@property (nonatomic, readonly, assign) pthread_key_t currentDatabaseKey;

@property (nonatomic, readonly, assign) pthread_key_t previousDatabaseKey;

@end

@implementation FRZStore

#pragma mark Lifecycle

- (void)dealloc {
	[_changesSubject sendCompleted];

	pthread_key_delete(_activeTransactionCountKey);
	pthread_key_delete(_queuedChangesKey);
	pthread_key_delete(_currentDatabaseKey);
	pthread_key_delete(_previousDatabaseKey);
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

	pthread_key_create(&_activeTransactionCountKey, NULL);
	pthread_key_create(&_queuedChangesKey, NULL);
	pthread_key_create(&_currentDatabaseKey, NULL);
	pthread_key_create(&_previousDatabaseKey, NULL);

	return self;
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

	FRZTransactor *transactor = [self transactor];
	success = [transactor addAttribute:FRZStoreHeadTransactionAttribute type:FRZAttributeTypeInteger withMetadata:NO error:error];
	if (!success) return NO;

	success = [transactor addAttribute:FRZStoreTransactionDateAttribute type:FRZAttributeTypeDate withMetadata:NO error:error];
	if (!success) return NO;

	success = [transactor addAttribute:FRZStoreAttributeTypeAttribute type:FRZAttributeTypeInteger withMetadata:NO error:error];
	if (!success) return NO;

	return YES;
}

#pragma mark Attributes

- (NSString *)tableNameForAttribute:(NSString *)attribute {
	NSParameterAssert(attribute != nil);

	return [NSString stringWithFormat:@"[%@]", attribute];
}

#pragma mark Properties

- (NSString *)selectHeadValueQuery {
	static dispatch_once_t onceToken;
	static NSString *query;
	dispatch_once(&onceToken, ^{
		NSString *tableName = [self tableNameForAttribute:FRZStoreHeadTransactionAttribute];
		query = [NSString stringWithFormat:@"SELECT value FROM %@ WHERE key = 'head' ORDER BY id DESC LIMIT 1", tableName];
	});

	return query;
}

- (long long int)headID {
	// NB: This can't go through the standard FRZDatabase method of retrieval
	// because that needs to call -headID to fix the FRZDatabase to the current
	// head. :cry:
	FMDatabase *database = [self databaseForCurrentThread:NULL];
	if (database == nil) return -1;

	NSString *query = self.selectHeadValueQuery;
	FMResultSet *set = [database executeQuery:query];
	if (set == nil) return -1;
	if (![set next]) return -1;

	return [set longLongIntForColumnIndex:0];
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

- (BOOL)performTransactionType:(FRZStoreTransactionType)transactionType error:(NSError **)error block:(BOOL (^)(FMDatabase *database, NSError **error))block {
	NSParameterAssert(block != NULL);

	FMDatabase *database = [self databaseForCurrentThread:error];
	if (database == nil) return NO;

	if ([self incrementTransactionCount] == 1) {
		NSDictionary *transactionTypeToName = @{
			@(FRZStoreTransactionTypeDeferred): @"deferred",
			@(FRZStoreTransactionTypeImmediate): @"immediate",
			@(FRZStoreTransactionTypeExclusive): @"exclusive",
		};

		NSString *transactionTypeName = transactionTypeToName[@(transactionType)];
		NSAssert(transactionTypeName != nil, @"Unrecognized transaction type: %ld", transactionType);
		[database executeUpdate:[NSString stringWithFormat:@"begin %@ transaction", transactionTypeName]];

		FRZDatabase *previousDatabase = [self currentDatabase];
		if (previousDatabase != nil) {
			pthread_setspecific(self.previousDatabaseKey, CFBridgingRetain(previousDatabase));
		}
	}

	BOOL success = block(database, error);
	if (!success) {
		[database rollback];
	} else {
		if ([self decrementTransactionCount] == 0) {
			FRZDatabase *changedDatabase = [self currentDatabase];

			[database commit];

			FRZDatabase *previousDatabase = (__bridge id)pthread_getspecific(self.previousDatabaseKey);

			NSArray *queuedChanges = [self.queuedChanges copy];
			[self.queuedChanges removeAllObjects];
			for (FRZChange *change in queuedChanges) {
				change.previousDatabase = previousDatabase;
				change.changedDatabase = changedDatabase;
				[self.changesSubject sendNext:change];
			}
		}
	}

	return success;
}

@end
