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

- (BOOL)applyChangesWithError:(NSError **)error block:(BOOL (^)(NSError **error))block {
	return [self.coordinator performTransactionType:DABCoordinatorTransactionTypeExclusive error:error block:^(FMDatabase *database, NSError **error) {
		return block(error);
	}];
}

- (BOOL)insertIntoDatabase:(FMDatabase *)database value:(id)value forAttribute:(NSString *)attribute key:(NSString *)key transactionID:(sqlite_int64)transactionID error:(NSError **)error {
	NSParameterAssert(database != nil);
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	id valueData = NSNull.null;
	if (value != NSNull.null) {
		valueData = [NSKeyedArchiver archivedDataWithRootObject:value];
	}

	BOOL success = [database executeUpdate:@"INSERT INTO entities (attribute, value, key, tx_id) VALUES (?, ?, ?, ?)", attribute, valueData, key, @(transactionID)];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	return YES;
}

- (sqlite_int64)insertNewTransactionIntoDatabase:(FMDatabase *)database error:(NSError **)error {
	NSParameterAssert(database != nil);

	long long int headID = [self.coordinator headID:error];
	NSString *txKey = [self generateNewKey];
	BOOL success = [self insertIntoDatabase:database value:[NSDate date] forAttribute:@"date" key:txKey transactionID:headID error:error];
	if (!success) return -1;

	return database.lastInsertRowId;
}

- (BOOL)addValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	// We could split some of this work out into a non-exclusive transaction,
	// but by batching it all in a single transaction we get a much higher write
	// speed. (~370 w/s vs. ~600 w/s on my computer).
	//
	// TODO: Test whether the write cost of splitting it up is made up in read
	// speed.
	return [self.coordinator performTransactionType:DABCoordinatorTransactionTypeExclusive error:error block:^(FMDatabase *database, NSError **error) {
		sqlite_int64 txID = [self insertNewTransactionIntoDatabase:database error:error];
		if (txID < 0) return NO;

		BOOL success = [self insertIntoDatabase:database value:value forAttribute:attribute key:key transactionID:txID error:error];
		if (!success) return NO;

		return [self updateHeadInDatabase:database toID:txID error:error];
	}];
}

- (BOOL)removeValueForAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error {
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	return [self.coordinator performTransactionType:DABCoordinatorTransactionTypeExclusive error:error block:^(FMDatabase *database, NSError **error) {
		sqlite_int64 txID = [self insertNewTransactionIntoDatabase:database error:error];
		if (txID < 0) return NO;

		BOOL success = [self insertIntoDatabase:database value:NSNull.null forAttribute:attribute key:key transactionID:txID error:error];
		if (!success) return NO;

		return [self updateHeadInDatabase:database toID:txID error:error];
	}];
}

- (BOOL)updateHeadInDatabase:(FMDatabase *)database toID:(sqlite_int64)ID error:(NSError **)error {
	NSParameterAssert(database != nil);

	FMResultSet *set = [database executeQuery:@"SELECT id FROM entities WHERE key = ? LIMIT 1", @"head"];
	if (![set next]) {
		// TODO: Do we want transaction IDs for a transaction? What does it mean?!
		return [self insertIntoDatabase:database value:@(ID) forAttribute:@"id" key:@"head" transactionID:0 error:error];
	} else {
		NSData *txIDData = [NSKeyedArchiver archivedDataWithRootObject:@(ID)];
		return [database executeUpdate:@"UPDATE entities SET value = ? WHERE key = ?", txIDData, @"head"];
	}
}

@end
