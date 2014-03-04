//
//  FRZTransactor.m
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZTransactor.h"
#import "FRZDatabase+Private.h"
#import "FRZStore.h"
#import "FRZStore+Private.h"
#import "FMDatabase.h"
#import "FRZChange+Private.h"
#import "FRZDeletedSentinel.h"

@interface FRZTransactor ()

@property (nonatomic, readonly, strong) FRZStore *store;

@end

@implementation FRZTransactor

#pragma mark Lifecycle

- (id)initWithStore:(FRZStore *)store {
	NSParameterAssert(store != nil);

	self = [super init];
	if (self == nil) return nil;

	_store = store;

	return self;
}

#pragma mark Changing

- (NSString *)generateNewID {
	// Problem?
	return [@"user/" stringByAppendingString:[[NSUUID UUID] UUIDString]];
}

- (BOOL)performChangesWithError:(NSError **)error block:(BOOL (^)(NSError **error))block {
	NSParameterAssert(block != NULL);

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		return block(error);
	}];
}

- (BOOL)insertIntoDatabase:(FMDatabase *)database value:(id)value forKey:(NSString *)key ID:(NSString *)ID transactionID:(long long int)transactionID error:(NSError **)error {
	NSParameterAssert(database != nil);
	NSParameterAssert(value != nil);
	NSParameterAssert(key != nil);
	NSParameterAssert(ID != nil);

	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:value];
	BOOL success = [database executeUpdate:@"INSERT INTO data (key, value, frz_id, tx_id) VALUES (?, ?, ?, ?)", key, data, ID, @(transactionID)];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	return YES;
}

- (long long int)insertNewTransactionIntoDatabase:(FMDatabase *)database error:(NSError **)error {
	NSParameterAssert(database != nil);

	BOOL success = [self insertIntoDatabase:database value:[NSDate date] forKey:FRZStoreTransactionDateKey ID:@"head" transactionID:0 error:error];
	if (!success) return -1;

	return database.lastInsertRowId;
}

- (BOOL)addValue:(id<NSCoding>)value forKey:(NSString *)key ID:(NSString *)ID error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(key != nil);
	NSParameterAssert(ID != nil);

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		BOOL success = [self insertIntoDatabase:database value:value forKey:key ID:ID transactionID:txID error:error];
		if (!success) return NO;

		[self.store.queuedChanges addObject:[[FRZChange alloc] initWithType:FRZChangeTypeAdd ID:ID key:key delta:value]];

		return YES;
	}];
}

- (BOOL)addValues:(NSDictionary *)keyedValues forID:(NSString *)ID error:(NSError **)error {
	NSParameterAssert(keyedValues != nil);
	NSParameterAssert(ID != nil);

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		for (NSString *key in keyedValues) {
			id value = keyedValues[key];
			BOOL success = [self addValue:value forKey:key ID:ID error:error];
			if (!success) return NO;
		}

		return YES;
	}];
}

- (BOOL)removeValueForKey:(NSString *)key ID:(NSString *)ID error:(NSError **)error {
	NSParameterAssert(key != nil);
	NSParameterAssert(ID != nil);

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		FRZDatabase *previousDatabase = self.store.databaseBeforeTransaction;
		BOOL success = [self insertIntoDatabase:database value:FRZDeletedSentinel.deletedSentinel forKey:key ID:ID transactionID:txID error:error];
		if (!success) return NO;

		id value = [previousDatabase valueForID:ID key:key];
		[self.store.queuedChanges addObject:[[FRZChange alloc] initWithType:FRZChangeTypeRemove ID:ID key:key delta:value]];

		return YES;
	}];
}

- (BOOL)pushValue:(id<NSCoding>)value forKey:(NSString *)key ID:(NSString *)ID error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(key != nil);
	NSParameterAssert(ID != nil);

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		NSSet *existingSet = self.store.databaseBeforeTransaction[ID][key] ?: [NSSet set];
		NSSet *newSet = [existingSet setByAddingObject:value];
		return [self addValue:newSet forKey:key ID:ID error:error];
	}];
}

- (BOOL)removeValue:(id)value forKey:(NSString *)key ID:(NSString *)ID error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(key != nil);
	NSParameterAssert(ID != nil);

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		FRZDatabase *previousDatabase = self.store.databaseBeforeTransaction;
		NSSet *existingSet = [previousDatabase valueForID:ID key:key];
		NSMutableSet *newSet = [existingSet mutableCopy];
		[newSet removeObject:value];

		BOOL success = [self insertIntoDatabase:database value:newSet forKey:key ID:ID transactionID:txID error:error];
		if (!success) return NO;

		[self.store.queuedChanges addObject:[[FRZChange alloc] initWithType:FRZChangeTypeRemove ID:ID key:key delta:value]];

		return YES;
	}];
}

- (BOOL)updateHeadInDatabase:(FMDatabase *)database toID:(long long int)ID error:(NSError **)error {
	NSParameterAssert(database != nil);

	return [self insertIntoDatabase:database value:@(ID) forKey:FRZStoreHeadTransactionKey ID:@"head" transactionID:0 error:error];
}

#pragma mark Trimming

- (NSString *)placeholderWithCount:(NSUInteger)placeholderCount {
	NSMutableString *placeholder = [NSMutableString string];
	for (NSUInteger i = 0; i < placeholderCount; i++) {
		if (i == 0) {
			[placeholder appendString:@"?"];
		} else {
			[placeholder appendString:@", ?"];
		}
	}

	return placeholder;
}

- (BOOL)trimOldIDs:(FMDatabase *)database error:(NSError **)error {
	// Remove the IDs of deleted entries.
	//
	// 1. Get all the IDs in the head of the database.
	// 2. Delete any entries with an ID not in that set.
	FRZDatabase *currentDatabase = self.store.databaseBeforeTransaction;
	NSArray *keys = currentDatabase.allIDs.allObjects;
	NSString *query = [NSString stringWithFormat:@"DELETE FROM data WHERE frz_id NOT IN (%@)", [self placeholderWithCount:keys.count]];
	BOOL success = [database executeUpdate:query withArgumentsInArray:keys];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	return YES;
}

- (BOOL)trimOldValues:(FMDatabase *)database error:(NSError **)error {
	// Remove old values of existing entries.
	//
	// 1. Get the IDs for all the latest values for the keys.
	// 2. Delete any entries with an ID not in that set.
	FRZDatabase *currentDatabase = self.store.databaseBeforeTransaction;
	for (NSString *ID in currentDatabase.allIDs) {
		FMResultSet *set = [database executeQuery:@"SELECT id FROM data WHERE frz_id = ? GROUP BY key ORDER BY tx_id DESC", ID];
		if (set == nil) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		NSMutableArray *IDs = [NSMutableArray array];
		while ([set next]) {
			id ID = set[0];
			[IDs addObject:ID];
		}

		NSString *deleteQuery = [NSString stringWithFormat:@"DELETE FROM data WHERE frz_id = ? AND id NOT IN (%@)", [self placeholderWithCount:IDs.count]];
		BOOL success = [database executeUpdate:deleteQuery withArgumentsInArray:[@[ ID ] arrayByAddingObjectsFromArray:IDs]];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}
	}

	return YES;
}

- (BOOL)deleteEverythingButTheLastIDWithKey:(NSString *)key database:(FMDatabase *)database error:(NSError **)error {
	FMResultSet *set = [database executeQuery:@"SELECT id FROM data WHERE key = ? ORDER BY id DESC LIMIT 1", key];
	if (set == nil) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	if (![set next]) return YES;

	NSString *headID = set[0];
	BOOL success = [database executeUpdate:@"DELETE FROM data WHERE key = ? AND id != ?", key, headID];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	return YES;
}

- (BOOL)trimOldTransactions:(FMDatabase *)database error:(NSError **)error {
	BOOL success = [self deleteEverythingButTheLastIDWithKey:FRZStoreTransactionDateKey database:database error:error];
	if (!success) return NO;

	return [self deleteEverythingButTheLastIDWithKey:FRZStoreHeadTransactionKey database:database error:error];
}

- (BOOL)trim:(NSError **)error {
	return [self.store performTransactionType:FRZStoreTransactionTypeExclusive withNewTransaction:NO error:error block:^(FMDatabase *database, long long txID, NSError **error) {
		BOOL success = [self trimOldIDs:database error:error];
		if (!success) return NO;

		success = [self trimOldValues:database error:error];
		if (!success) return NO;

		return [self trimOldTransactions:database error:error];
	}];
}

@end
