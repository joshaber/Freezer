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

static NSString * const FRZStoreDatabaseKey = @"FRZStoreDatabaseKey";
static NSString * const FRZStoreActiveTransactionCountKey = @"FRZStoreActiveTransactionCountKey";

@interface FRZStore ()

@property (nonatomic, readonly, copy) NSString *databasePath;

@end

@implementation FRZStore

#pragma mark Lifecycle

- (id)initWithPath:(NSString *)path error:(NSError **)error {
	self = [super init];
	if (self == nil) return nil;

	_databasePath = [path copy];

	// Preflight the database so we get fatal errors earlier.
	FMDatabase *database = [self createDatabase:error];
	if (database == nil) return nil;

	return self;
}

- (id)initInMemory:(NSError **)error {
	return [self initWithPath:nil error:error];
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

- (FMDatabase *)createAndConfigureDatabase:(NSError **)error {
	FMDatabase *database = [self createDatabase:error];
	if (database == nil) return nil;

	database.shouldCacheStatements = YES;

	BOOL success = [database executeUpdate:@"PRAGMA legacy_file_format = 0;"];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return nil;
	}

	success = [database executeUpdate:@"PRAGMA foreign_keys = ON;"];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return nil;
	}

	// Write-ahead logging is usually faster and offers better concurrency.
	//
	// Note that we're using -executeQuery: here, instead of -executeUpdate: The
	// result of turning on WAL is a row, which really rustles FMDB's jimmies if
	// done from -executeUpdate. So we pacify it by setting WAL in a "query."
	FMResultSet *set = [database executeQuery:@"PRAGMA journal_mode = WAL;"];
	if (set == nil) {
		if (error != NULL) *error = database.lastError;
		return nil;
	}

	NSString *txsSchema =
		@"CREATE TABLE IF NOT EXISTS entities("
			"id INTEGER PRIMARY KEY AUTOINCREMENT,"
			"key STRING NOT NULL,"
			"attribute STRING NOT NULL,"
			"value BLOB,"
			"tx_id INTEGER NOT NULL"
		");";
	success = [database executeUpdate:txsSchema];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return nil;
	}

	return database;
}

#pragma mark Properties

- (long long int)headID:(NSError **)error {
	long long int headID = -1;
	FMDatabase *database = [self databaseForCurrentThread:error];
	if (database == nil) return -1;

	FMResultSet *set = [database executeQuery:@"SELECT value FROM entities WHERE key = ? LIMIT 1", @"head"];
	if ([set next]) {
		NSData *headIDData = [set objectForColumnIndex:0];
		headID = [[NSKeyedUnarchiver unarchiveObjectWithData:headIDData] longLongValue];
	}

	return headID;
}

- (FRZDatabase *)currentDatabase:(NSError **)error {
	long long int headID = [self headID:error];
	if (headID < 0) return nil;

	return [[FRZDatabase alloc] initWithStore:self headID:headID];
}

- (FMDatabase *)databaseForCurrentThread:(NSError **)error {
	FMDatabase *database = NSThread.currentThread.threadDictionary[FRZStoreDatabaseKey];
	if (database == nil) {
		database = [self createAndConfigureDatabase:error];
		if (database == nil) return nil;

		NSThread.currentThread.threadDictionary[FRZStoreDatabaseKey] = database;
	}

	return database;
}

- (FRZTransactor *)transactor {
	return [[FRZTransactor alloc] initWithStore:self];
}

#pragma mark Transactions

- (NSInteger)incrementTransactionCount {
	NSInteger transactionCount = [NSThread.currentThread.threadDictionary[FRZStoreActiveTransactionCountKey] integerValue];
	transactionCount++;
	NSThread.currentThread.threadDictionary[FRZStoreActiveTransactionCountKey] = @(transactionCount);
	return transactionCount;
}

- (NSInteger)deccrementTransactionCount {
	NSInteger transactionCount = [NSThread.currentThread.threadDictionary[FRZStoreActiveTransactionCountKey] integerValue];
	transactionCount--;
	NSThread.currentThread.threadDictionary[FRZStoreActiveTransactionCountKey] = @(transactionCount);
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
		}
	}

	return success;
}

@end
