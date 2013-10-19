//
//  DABCoordinator.m
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABCoordinator.h"
#import "DABCoordinator+Private.h"
#import <ObjectiveGit/ObjectiveGit.h>
#import "DABDatabase+Private.h"
#import "DABTransactor+Private.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"

static NSString * const DABCoordinatorRefsTableName = @"refs";
static NSString * const DABCoordinatorEntitiesTableName = @"entities";
static NSString * const DABCoordinatorTransactionsTableName = @"txs";
static NSString * const DABCoordinatorTransactionToEntityTableName = @"tx_to_entity";

@interface DABCoordinator ()

@property (nonatomic, readonly, strong) dispatch_queue_t databaseQueue;

@property (nonatomic, readonly, strong) FMDatabase *underlyingDatabase;

@property (nonatomic, readonly, strong) GTRepository *repository;

@end

@implementation DABCoordinator

- (id)initWithPath:(NSString *)path error:(NSError **)error {
	self = [super init];
	if (self == nil) return nil;

	_databaseQueue = dispatch_queue_create("com.DatBase.DABCoordinator", 0);
	_underlyingDatabase = [FMDatabase databaseWithPath:path];
	if (_underlyingDatabase == nil) return nil;

	// No mutex allows multiple connections at once.
	BOOL success = [_underlyingDatabase openWithFlags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX];
	if (!success) {
		if (error != NULL) *error = _underlyingDatabase.lastError;
		return nil;
	}

	success = [_underlyingDatabase executeUpdate:@"PRAGMA foreign_keys = ON;"];
	if (!success) {
		if (error != NULL) *error = _underlyingDatabase.lastError;
		return nil;
	}

	// Write-ahead logging lets us read and write concurrently.
	success = [_underlyingDatabase executeUpdate:@"PRAGMA journal_mode = WAL;"];
	if (!success) {
		if (error != NULL) *error = _underlyingDatabase.lastError;
		return nil;
	}

	success = [self createTablesIfNeeded:error];
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

- (BOOL)createTablesIfNeeded:(NSError **)error {
	NSString *refsSchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"tx_id INTEGER NOT NULL,"
			"name TEXT NOT NULL,"
			"FOREIGN KEY(tx_id) REFERENCES %@(rowid)"
		");",
		DABCoordinatorRefsTableName,
		DABCoordinatorTransactionsTableName];
	BOOL success = [self.underlyingDatabase executeUpdate:refsSchema];
	if (!success) {
		if (error != NULL) *error = self.underlyingDatabase.lastError;
		return NO;
	}

	NSString *txsSchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"date DATETIME NOT NULL"
		");",
		DABCoordinatorTransactionsTableName];
	success = [self.underlyingDatabase executeUpdate:txsSchema];
	if (!success) {
		if (error != NULL) *error = self.underlyingDatabase.lastError;
		return NO;
	}

	NSString *entitiesSchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"attribute TEXT NOT NULL,"
			"value BLOB NOT NULL,"
			"tx_id INTEGER NOT NULL,"
			"FOREIGN KEY(tx_id) REFERENCES %@(rowid)"
		");",
		DABCoordinatorEntitiesTableName,
		DABCoordinatorTransactionsTableName];
	success = [self.underlyingDatabase executeUpdate:entitiesSchema];
	if (!success) {
		if (error != NULL) *error = self.underlyingDatabase.lastError;
		return NO;
	}

	NSString *txToEntitySchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"tx_id INTEGER NOT NULL,"
			"entity_id INTEGER NOT NULL,"
			"FOREIGN KEY(tx_id) REFERENCES %@(rowid),"
			"FOREIGN KEY(entity_id) REFERENCES %@(rowid)"
		");",
		DABCoordinatorTransactionToEntityTableName,
		DABCoordinatorTransactionsTableName,
		DABCoordinatorEntitiesTableName];
	success = [self.underlyingDatabase executeUpdate:txToEntitySchema];
	if (!success) {
		if (error != NULL) *error = self.underlyingDatabase.lastError;
		return NO;
	}

	return YES;
}

- (long long)headID {
	__block long long headID = 0;
	dispatch_sync(_databaseQueue, ^{
		FMResultSet *set = [self.underlyingDatabase executeQuery:@"SELECT tx_id from refs WHERE name = ? TAKE 1", @"HEAD"];
		if ([set next]) {
			headID = [set longLongIntForColumnIndex:0];
		}
	});

	return headID;
}

- (GTCommit *)HEADCommit:(NSError **)error {
	__block GTCommit *commit;

	[self performBlock:^(GTRepository *repository) {
		commit = [self.repository lookupObjectByRefspec:@"HEAD" error:error];
	}];

	return commit;
}

- (DABDatabase *)currentDatabase:(NSError **)error {
	GTCommit *commit = [self HEADCommit:error];
	return [[DABDatabase alloc] initWithCommit:commit];
}

- (void)performBlock:(void (^)(GTRepository *repository))block {
	NSParameterAssert(block != NULL);

	block(self.repository);
}

- (void)performAtomicBlock:(void (^)(GTRepository *repository))block {
	NSParameterAssert(block != NULL);

	@synchronized (self) {
		block(self.repository);
	}
}

- (DABTransactor *)transactor {
	return [[DABTransactor alloc] initWithCoordinator:self];
}

@end
