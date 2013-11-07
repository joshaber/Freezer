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

NSString * const FRZStoreHeadTransactionAttribute = @"Freezer/tx/head";
NSString * const FRZStoreTransactionDateAttribute = @"Freezer/tx/date";

@interface FRZStore ()

@property (nonatomic, readonly, strong) RACSubject *changesSubject;

@property (nonatomic, readonly, copy) NSString *databasePath;

@end

@implementation FRZStore

#pragma mark Lifecycle

- (void)dealloc {
	[_changesSubject sendCompleted];
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

	success = [database executeUpdate:@"PRAGMA foreign_keys = ON;"];
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

	success = [self addAttribute:FRZStoreHeadTransactionAttribute sqliteType:@"INTEGER" error:error];
	if (!success) return NO;

	success = [self addAttribute:FRZStoreTransactionDateAttribute sqliteType:@"DATETIME" error:error];
	if (!success) return NO;

	return YES;
}

- (NSString *)tableNameForAttribute:(NSString *)attribute {
	NSParameterAssert(attribute != nil);

	return [NSString stringWithFormat:@"[%@]", attribute];
}

- (BOOL)addAttribute:(NSString *)attribute sqliteType:(NSString *)sqliteType error:(NSError **)error {
	FMDatabase *database = [self databaseForCurrentThread:error];
	if (database == nil) return NO;

	NSString *tableName = [self tableNameForAttribute:attribute];
	NSString *schemaTemplate =
		@"CREATE TABLE IF NOT EXISTS %@("
			"id INTEGER PRIMARY KEY AUTOINCREMENT,"
			"key STRING NOT NULL,"
			"attribute STRING NOT NULL,"
			"value %@,"
			"tx_id INTEGER NOT NULL"
		");";

	NSString *schema = [NSString stringWithFormat:schemaTemplate, tableName, sqliteType];
	BOOL success = [database executeUpdate:schema];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	return YES;
}

#pragma mark Properties

- (long long int)headID:(NSError **)error {
	// NB: This can't go through the standard FRZDatabase method of retrieval
	// because that needs to call -headID to fix the FRZDatabase to the current
	// head. :cry:
	FMDatabase *database = [self databaseForCurrentThread:error];
	if (database == nil) return -1;

	NSString *tableName = [self tableNameForAttribute:FRZStoreHeadTransactionAttribute];
	NSString *query = [NSString stringWithFormat:@"SELECT value FROM %@ WHERE key = 'head' ORDER BY id DESC LIMIT 1", tableName];
	FMResultSet *set = [database executeQuery:query];
	if (set == nil) return -1;
	if (![set next]) return -1;

	return [set longLongIntForColumnIndex:0];
}

- (FRZDatabase *)currentDatabase:(NSError **)error {
	long long int headID = [self headID:error];
	if (headID < 0) return nil;

	return [[FRZDatabase alloc] initWithStore:self headID:headID];
}

- (FMDatabase *)databaseForCurrentThread:(NSError **)error {
	NSString *databaseKey = [@"com.joshaber.Freezer.FRZStore.database.%@" stringByAppendingString:self.databasePath];
	FMDatabase *database = NSThread.currentThread.threadDictionary[databaseKey];
	if (database == nil) {
		database = [self createDatabase:error];
		if (database == nil) return nil;

		NSThread.currentThread.threadDictionary[databaseKey] = database;

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
	NSString *queuedChangesKey = [@"com.joshaber.Freezer.FRZStore.queuedChanged.%@" stringByAppendingString:self.databasePath];
	NSMutableArray *array = NSThread.currentThread.threadDictionary[queuedChangesKey];
	if (array != nil) return array;

	array = [NSMutableArray array];
	NSThread.currentThread.threadDictionary[queuedChangesKey] = array;
	return array;
}

- (RACSignal *)changes {
	return self.changesSubject;
}

#pragma mark Transactions

- (NSString *)activeTransactionCountKey {
	return [@"com.joshaber.Freezer.FRZStore.activeTransactionCount.%@" stringByAppendingString:self.databasePath];
}

- (NSInteger)incrementTransactionCount {
	NSInteger transactionCount = [NSThread.currentThread.threadDictionary[self.activeTransactionCountKey] integerValue];
	transactionCount++;
	NSThread.currentThread.threadDictionary[self.activeTransactionCountKey] = @(transactionCount);
	return transactionCount;
}

- (NSInteger)deccrementTransactionCount {
	NSInteger transactionCount = [NSThread.currentThread.threadDictionary[self.activeTransactionCountKey] integerValue];
	transactionCount--;
	NSThread.currentThread.threadDictionary[self.activeTransactionCountKey] = @(transactionCount);
	return transactionCount;
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
	}

	BOOL success = block(database, error);
	if (!success) {
		[database rollback];
	} else {
		if ([self deccrementTransactionCount] == 0) {
			[database commit];

			for (FRZChange *change in self.queuedChanges) {
				[self.changesSubject sendNext:change];
			}

			[self.queuedChanges removeAllObjects];
		}
	}

	return success;
}

@end
