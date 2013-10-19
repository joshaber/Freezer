//
//  DABDatabasePool.m
//  DatBase
//
//  Created by Josh Abernathy on 10/19/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABDatabasePool.h"
#import "FMDatabase.h"
#import "DABCoordinator+Private.h"

static NSString * const DABDatabasePoolCurrentThreadDB = @"DABDatabasePoolCurrentThreadDB";

@interface DABDatabasePool ()

@property (nonatomic, readonly, copy) NSString *path;

@end

@implementation DABDatabasePool

- (id)initWithDatabaseAtPath:(NSString *)path {
	NSParameterAssert(path != nil);

	self = [super init];
	if (self == nil) return nil;

	_path = [path copy];

	return self;
}

- (FMDatabase *)databaseForCurrentThread:(NSError **)error {
	@synchronized (self) {
		FMDatabase *database = NSThread.currentThread.threadDictionary[DABDatabasePoolCurrentThreadDB];
		if (database == nil) {
			database = [[FMDatabase alloc] initWithPath:self.path];
			// No mutex, no cry.
			BOOL success = [database openWithFlags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_PRIVATECACHE];
			if (!success) {
				if (error != NULL) *error = database.lastError;
				return nil;
			}

			success = [self configureDatabase:database error:error];
			if (!success) return nil;

			NSThread.currentThread.threadDictionary[DABDatabasePoolCurrentThreadDB] = database;
		}

		return database;
	}
}

- (BOOL)configureDatabase:(FMDatabase *)database error:(NSError **)error {
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

	// Write-ahead logging lets us read and write concurrently.
	// LOL FMDB. The result of turning on WAL is a row, which really rustles
	// FMDB's jimmies if done from -executeUpdate. So we pacify it by setting
	// WAL in a "query."
	FMResultSet *set = [database executeQuery:@"PRAGMA journal_mode = WAL;"];
	if (set == nil) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	NSString *refsSchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"tx_id INTEGER NOT NULL,"
			"name TEXT NOT NULL,"
			"FOREIGN KEY(tx_id) REFERENCES %@(rowid)"
		");",
		DABRefsTableName,
		DABTransactionsTableName];
	success = [database executeUpdate:refsSchema];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	NSString *txsSchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"date DATETIME NOT NULL"
		");",
		DABTransactionsTableName];
	success = [database executeUpdate:txsSchema];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	NSString *entitiesSchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"attribute TEXT NOT NULL,"
			"value BLOB NOT NULL,"
			"tx_id INTEGER NOT NULL,"
			"FOREIGN KEY(tx_id) REFERENCES %@(rowid)"
		");",
		DABEntitiesTableName,
		DABTransactionsTableName];
	success = [database executeUpdate:entitiesSchema];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	NSString *txToEntitySchema = [NSString stringWithFormat:
		@"CREATE TABLE IF NOT EXISTS %@("
			"tx_id INTEGER NOT NULL,"
			"entity_id INTEGER NOT NULL,"
			"FOREIGN KEY(tx_id) REFERENCES %@(rowid),"
			"FOREIGN KEY(entity_id) REFERENCES %@(rowid)"
		");",
		DABTransactionToEntityTableName,
		DABTransactionsTableName,
		DABEntitiesTableName];
	success = [database executeUpdate:txToEntitySchema];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	return YES;
}

@end
