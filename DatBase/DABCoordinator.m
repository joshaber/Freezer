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

NSString * const DABRefsTableName = @"refs";
NSString * const DABEntitiesTableName = @"entities";
NSString * const DABTransactionsTableName = @"txs";
NSString * const DABTransactionToEntityTableName = @"tx_to_entity";

NSString * const DABHeadRefName = @"head";

@interface DABCoordinator ()

@property (nonatomic, readonly, strong) dispatch_queue_t databaseQueue;

@property (nonatomic, readonly, strong) FMDatabase *database;

@end

@implementation DABCoordinator

- (void)dealloc {
	[_database close];
}

- (id)initWithPath:(NSString *)path error:(NSError **)error {
	self = [super init];
	if (self == nil) return nil;

	_databaseQueue = dispatch_queue_create("com.DatBase.DABCoordinator", DISPATCH_QUEUE_CONCURRENT);
	_database = [[FMDatabase alloc] initWithPath:path];
	// No mutex, no cry.
	BOOL success = [_database openWithFlags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_PRIVATECACHE];

	if (!success) {
		if (error != NULL) *error = _database.lastError;
		return nil;
	}

	success = [self configureDatabase:error];
	if (!success) return nil;

	return self;
}

- (id)initInMemory:(NSError **)error {
	return [self initWithPath:nil error:error];
}

- (id)initWithDatabaseAtURL:(NSURL *)URL error:(NSError **)error {
	NSParameterAssert(URL != nil);

	return [self initWithPath:URL.path error:error];
}

- (BOOL)configureDatabase:(NSError **)error {
	self.database.shouldCacheStatements = YES;

	BOOL success = [self.database executeUpdate:@"PRAGMA legacy_file_format = 0;"];
	if (!success) {
		if (error != NULL) *error = self.database.lastError;
		return NO;
	}

	success = [self.database executeUpdate:@"PRAGMA foreign_keys = ON;"];
	if (!success) {
		if (error != NULL) *error = self.database.lastError;
		return NO;
	}

	// Write-ahead logging lets us read and write concurrently.
	//
	// Note that we're using -executeQuery: here, instead of -executeUpdate: The
	// result of turning on WAL is a row, which really rustles FMDB's jimmies if
	// done from -executeUpdate. So we pacify it by setting WAL in a "query."
	FMResultSet *set = [self.database executeQuery:@"PRAGMA journal_mode = WAL;"];
	if (set == nil) {
		if (error != NULL) *error = self.database.lastError;
		return NO;
	}

	NSString *txsSchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"id INTEGER PRIMARY KEY AUTOINCREMENT,"
			"date DATETIME NOT NULL"
		");",
		DABTransactionsTableName];
	success = [self.database executeUpdate:txsSchema];
	if (!success) {
		if (error != NULL) *error = self.database.lastError;
		return NO;
	}

	NSString *refsSchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"id INTEGER PRIMARY KEY AUTOINCREMENT,"
			"tx_id INTEGER NOT NULL,"
			"name TEXT NOT NULL,"
			"FOREIGN KEY(tx_id) REFERENCES %@(id)"
		");",
		DABRefsTableName,
		DABTransactionsTableName];
	success = [self.database executeUpdate:refsSchema];
	if (!success) {
		if (error != NULL) *error = self.database.lastError;
		return NO;
	}

	NSString *entitiesSchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"id INTEGER PRIMARY KEY AUTOINCREMENT,"
			"attribute TEXT NOT NULL,"
			"value BLOB NOT NULL,"
			"key STRING NOT NULL,"
			"tx_id INTEGER NOT NULL,"
			"FOREIGN KEY(tx_id) REFERENCES %@(id)"
		");",
		DABEntitiesTableName,
		DABTransactionsTableName];
	success = [self.database executeUpdate:entitiesSchema];
	if (!success) {
		if (error != NULL) *error = self.database.lastError;
		return NO;
	}

	NSString *txToEntitySchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"tx_id INTEGER NOT NULL,"
			"entity_id INTEGER NOT NULL,"
			"FOREIGN KEY(tx_id) REFERENCES %@(id),"
			"FOREIGN KEY(entity_id) REFERENCES %@(id)"
		");",
		DABTransactionToEntityTableName,
		DABTransactionsTableName,
		DABEntitiesTableName];
	success = [self.database executeUpdate:txToEntitySchema];
	if (!success) {
		if (error != NULL) *error = self.database.lastError;
		return NO;
	}

	return YES;
}

- (long long int)headID:(NSError **)error {
	long long int headID = 0;
	NSString *query = [NSString stringWithFormat:@"SELECT tx_id from %@ WHERE name = ? LIMIT 1", DABRefsTableName];
	FMResultSet *set = [self.database executeQuery:query, DABHeadRefName];
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

- (void)performConcurrentBlock:(void (^)(FMDatabase *database))block {
	NSParameterAssert(block != NULL);

	// TODO: Can this be concurrent? Sqlite docs are unclear about WAL mode. If
	// not, we could use a thread-local db connection instead. For now we'll
	// play it safe.
	dispatch_barrier_sync(self.databaseQueue, ^{
		block(self.database);
	});
}

- (void)performExclusiveBlock:(void (^)(FMDatabase *database))block {
	NSParameterAssert(block != NULL);

	dispatch_barrier_sync(self.databaseQueue, ^{
		block(self.database);
	});
}

- (DABTransactor *)transactor {
	return [[DABTransactor alloc] initWithCoordinator:self];
}

@end
