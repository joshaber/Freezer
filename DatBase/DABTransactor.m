//
//  DABTransactor.m
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABTransactor.h"
#import "DABDatabase+Private.h"
#import "DABCoordinator.h"
#import "DABCoordinator+Private.h"
#import "FMDatabase.h"

@interface DABTransactor ()

@property (nonatomic, readonly, strong) DABCoordinator *coordinator;

@end

@implementation DABTransactor

- (id)initWithCoordinator:(DABCoordinator *)coordinator {
	NSParameterAssert(coordinator != nil);

	self = [super init];
	if (self == nil) return nil;

	_coordinator = coordinator;

	return self;
}

- (void)runTransaction:(void (^)(void))block {
	NSParameterAssert(block != NULL);

	[self.coordinator performExclusiveBlock:^(FMDatabase *database) {
		block();
	}];
}

- (NSString *)generateNewKey {
	// Problem?
	return [[NSUUID UUID] UUIDString];
}

- (BOOL)addValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	__block BOOL totalSuccess = NO;
	[self.coordinator performExclusiveBlock:^(FMDatabase *database) {
		NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ (date) VALUES (?)", DABTransactionsTableName];
		BOOL success = [database executeUpdate:query, [NSDate date]];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return;
		}

		// This is guaranteed to be accurate since we have an exclusive lock on
		// the database while writing.
		sqlite_int64 txID = database.lastInsertRowId;

		query = [NSString stringWithFormat:@"INSERT INTO %@ (attribute, value, key, tx_id) VALUES (?, ?, ?, ?)", DABEntitiesTableName];
		NSData *valueData = [NSKeyedArchiver archivedDataWithRootObject:value];
		success = [database executeUpdate:query, attribute, valueData, key, @(txID)];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return;
		}

		sqlite_int64 entityID = database.lastInsertRowId;

		query = [NSString stringWithFormat:@"INSERT INTO %@ (tx_id, entity_id) VALUES (?, ?)", DABTransactionToEntityTableName];
		success = [database executeUpdate:query, @(txID), @(entityID)];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return;
		}

		// We can get away with doing the two-step check since we have a lock on
		// the database.
		query = [NSString stringWithFormat:@"SELECT 1 FROM %@ WHERE name = ? LIMIT 1", DABRefsTableName];
		FMResultSet *set = [database executeQuery:query, DABHeadRefName];
		if (!set.hasAnotherRow) {
			query = [NSString stringWithFormat:@"INSERT INTO %@ (tx_id, name) VALUES (?, ?)", DABRefsTableName];
		} else {
			query = [NSString stringWithFormat:@"UPDATE %@ SET tx_id = ? WHERE name = ?", DABRefsTableName];
		}

		success = [database executeUpdate:query, @(txID), DABHeadRefName];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return;
		}

		totalSuccess = YES;
	}];

	return totalSuccess;
}

@end
