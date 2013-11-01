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

	return [self.coordinator performWithError:error block:^(FMDatabase *database, NSError **error) {
		long long int headID = [self.coordinator headID:error];

		NSString *query = [NSString stringWithFormat:@"SELECT entity_id FROM %@ WHERE tx_id = ?", DABTransactionToEntityTableName];
		FMResultSet *set = [database executeQuery:query, @(headID)];
		NSMutableArray *IDs = [NSMutableArray array];
		while ([set next]) {
			long long int entityID = [set longLongIntForColumnIndex:0];
			[IDs addObject:@(entityID)];
		}

		query = [NSString stringWithFormat:@"INSERT INTO %@ (date) VALUES (?)", DABTransactionsTableName];
		BOOL success = [database executeUpdate:query, [NSDate date]];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		sqlite_int64 txID = database.lastInsertRowId;

		query = [NSString stringWithFormat:@"INSERT INTO %@ (attribute, value, key, tx_id) VALUES (?, ?, ?, ?)", DABEntitiesTableName];
		NSData *valueData = [NSKeyedArchiver archivedDataWithRootObject:value];
		success = [database executeUpdate:query, attribute, valueData, key, @(txID)];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		sqlite_int64 entityID = database.lastInsertRowId;

		NSNumber *transactionID = @(txID);
		[IDs addObject:@(entityID)];
		for (NSNumber *entityID in IDs) {
			query = [NSString stringWithFormat:@"INSERT INTO %@ (tx_id, entity_id) VALUES (?, ?)", DABTransactionToEntityTableName];
			success = [database executeUpdate:query, transactionID, entityID];
			if (!success) {
				if (error != NULL) *error = database.lastError;
				return NO;
			}
		}

		query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE name = ? LIMIT 1", DABRefsTableName];
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
