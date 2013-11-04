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

- (NSString *)generateNewKey {
	// Problem?
	return [[NSUUID UUID] UUIDString];
}

- (BOOL)addValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	NSDate *currentDate = [NSDate date];
	NSData *valueData = [NSKeyedArchiver archivedDataWithRootObject:value];

	// We could split some of this work out into a non-exclusive transaction,
	// but by batching it all in a single transaction we get a much higher write
	// speed. (~370 w/s vs. ~600 w/s on my computer).
	//
	// TODO: Test whether the write cost of splitting it up is made up in read
	// speed.
	return [self.coordinator performTransactionType:DABCoordinatorTransactionTypeExclusive error:error block:^(FMDatabase *database, NSError **error) {
		NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ (date) VALUES (?)", DABTransactionsTableName];
		BOOL success = [database executeUpdate:query, currentDate];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		sqlite_int64 txID = database.lastInsertRowId;

		query = [NSString stringWithFormat:@"INSERT INTO %@ (attribute, value, key, tx_id) VALUES (?, ?, ?, ?)", DABEntitiesTableName];
		success = [database executeUpdate:query, attribute, valueData, key, @(txID)];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		sqlite_int64 addedEntityID = database.lastInsertRowId;

		long long int headID = [self.coordinator headID:error];

		// TODO: Surely there's a better way to do all this?
		query = [NSString stringWithFormat:@"SELECT entity_id, entity_key FROM %@ WHERE tx_id = ?", DABTransactionToEntityTableName];
		FMResultSet *set = [database executeQuery:query, @(headID)];
		NSMutableDictionary *keysToIDs = [NSMutableDictionary dictionary];
		while ([set next]) {
			NSString *entityKey = [set stringForColumnIndex:1];
			long long int entityID = [set longLongIntForColumnIndex:0];
			keysToIDs[entityKey] = @(entityID);
		}

		NSNumber *transactionID = @(addedEntityID);
		keysToIDs[key] = transactionID;
		for (NSString *entityKey in keysToIDs) {
			NSNumber *entityID = keysToIDs[entityKey];
			query = [NSString stringWithFormat:@"INSERT INTO %@ (tx_id, entity_id, entity_key) VALUES (?, ?, ?)", DABTransactionToEntityTableName];
			BOOL success = [database executeUpdate:query, transactionID, entityID, entityKey];
			if (!success) {
				if (error != NULL) *error = database.lastError;
				return NO;
			}
		}

		query = [NSString stringWithFormat:@"SELECT name FROM %@ WHERE name = ? LIMIT 1", DABRefsTableName];
		set = [database executeQuery:query, DABHeadRefName];
		if (![set next]) {
			query = [NSString stringWithFormat:@"INSERT INTO %@ (tx_id, name) VALUES (?, ?)", DABRefsTableName];
		} else {
			query = [NSString stringWithFormat:@"UPDATE %@ SET tx_id = ? WHERE name = ?", DABRefsTableName];
		}

		success = [database executeUpdate:query, @(txID), DABHeadRefName];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		return YES;
	}];
}

@end
