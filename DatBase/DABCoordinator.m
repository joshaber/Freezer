//
//  DABCoordinator.m
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABCoordinator.h"
#import "DABCoordinator+Private.h"
#import "DABDatabase+Private.h"
#import "DABTransactor+Private.h"
#import "FMDatabase.h"

static NSString * const DABCoordinatorDatabaseKey = @"DABCoordinatorDatabaseKey";

@interface DABCoordinator ()

@property (atomic, assign) BOOL inTransaction;

@property (nonatomic, readonly, copy) NSString *databasePath;

@end

@implementation DABCoordinator

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

- (id)initWithDatabaseAtURL:(NSURL *)URL error:(NSError **)error {
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
		@"CREATE TABLE IF NOT EXISTS entries("
			"id INTEGER PRIMARY KEY AUTOINCREMENT,"
			"entity STRING NOT NULL,"
			"value BLOB NOT NULL,"
			"tx_id INTEGER NOT NULL"
		");";
	success = [database executeUpdate:txsSchema];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return nil;
	}

	return database;
}

- (long long int)headID:(NSError **)error {
	long long int headID = -1;
	NSString *query = [NSString stringWithFormat:@"SELECT tx_id from %@ WHERE name = ? LIMIT 1", DABRefsTableName];
	FMDatabase *database = [self databaseForCurrentThread:error];
	if (database == nil) return -1;

	FMResultSet *set = [database executeQuery:query, DABHeadRefName];
	if ([set next]) {
		headID = [set longLongIntForColumnIndex:0];
	}

	return headID;
}

- (DABDatabase *)currentDatabase:(NSError **)error {
	long long int headID = [self headID:error];
	if (headID < 0) return nil;

	return [[DABDatabase alloc] initWithCoordinator:self transactionID:headID];
}

- (BOOL)performTransactionType:(DABCoordinatorTransactionType)transactionType error:(NSError **)error block:(BOOL (^)(FMDatabase *database, NSError **error))block {
	NSParameterAssert(block != NULL);

	FMDatabase *database = [self databaseForCurrentThread:error];
	if (database == nil) return NO;

	NSDictionary *transactionTypeToName = @{
		@(DABCoordinatorTransactionTypeDeferred): @"deferred",
		@(DABCoordinatorTransactionTypeImmediate): @"immediate",
		@(DABCoordinatorTransactionTypeExclusive): @"exclusive",
	};

	NSString *transactionTypeName = transactionTypeToName[@(transactionType)];
	NSAssert(transactionTypeName != nil, @"Unrecognized transaction type: %ld", transactionType);
	[database executeUpdate:[NSString stringWithFormat:@"begin %@ transaction", transactionTypeName]];

	self.inTransaction = YES;

	BOOL success = block(database, error);
	if (!success) {
		[database rollback];
	} else {
		[database commit];
	}

	self.inTransaction = NO;

	return success;
}

- (DABTransactor *)transactor {
	return [[DABTransactor alloc] initWithCoordinator:self];
}

- (FMDatabase *)databaseForCurrentThread:(NSError **)error {
	@synchronized (self) {
		FMDatabase *database = NSThread.currentThread.threadDictionary[DABCoordinatorDatabaseKey];
		if (database == nil) {
			database = [self createAndConfigureDatabase:error];
			if (database == nil) return nil;

			NSThread.currentThread.threadDictionary[DABCoordinatorDatabaseKey] = database;
		}

		return database;
	}
}

@end
