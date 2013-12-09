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
#import "FRZSingleKeyTransactor+Private.h"

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

#pragma mark Attributes

- (BOOL)addAttribute:(NSString *)attribute type:(FRZAttributeType)type collection:(BOOL)collection error:(NSError **)error {
	NSParameterAssert(attribute != nil);

	return [self.store performTransactionType:FRZStoreTransactionTypeExclusive withNewTransaction:YES error:error block:^(FMDatabase *database, long long txID, NSError **error) {
		BOOL success = [self insertIntoDatabase:database value:@(type) forAttribute:FRZStoreAttributeTypeAttribute key:attribute transactionID:txID error:error];
		if (!success) return NO;

		return [self insertIntoDatabase:database value:@(collection) forAttribute:FRZStoreAttributeIsCollectionAttribute key:attribute transactionID:txID error:error];
	}];
}

#pragma mark Changing

- (NSString *)generateNewKey {
	// Problem?
	return [@"user/" stringByAppendingString:[[NSUUID UUID] UUIDString]];
}

- (BOOL)performChangesWithError:(NSError **)error block:(BOOL (^)(NSError **error))block {
	NSParameterAssert(block != NULL);

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		return block(error);
	}];
}

- (NSError *)invalidAttributeErrorWithError:(NSError *)error {
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	userInfo[NSLocalizedDescriptionKey] = NSLocalizedString(@"Invalid attribute", @"");
	if (error != nil) userInfo[NSUnderlyingErrorKey] = error;
	return [NSError errorWithDomain:FRZErrorDomain code:FRZErrorInvalidAttribute userInfo:userInfo];
}

- (BOOL)insertIntoDatabase:(FMDatabase *)database data:(NSData *)data forAttribute:(NSString *)attribute key:(NSString *)key transactionID:(long long int)transactionID error:(NSError **)error {
	NSParameterAssert(database != nil);
	NSParameterAssert(data != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	BOOL success = [database executeUpdate:@"INSERT INTO data (attribute, value, key, tx_id) VALUES (?, ?, ?, ?)", attribute, data, key, @(transactionID)];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	return YES;
}

- (BOOL)insertIntoDatabase:(FMDatabase *)database value:(id)value forAttribute:(NSString *)attribute key:(NSString *)key transactionID:(long long int)transactionID error:(NSError **)error {
	NSParameterAssert(database != nil);
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	return [self insertIntoDatabase:database data:[NSKeyedArchiver archivedDataWithRootObject:value] forAttribute:attribute key:key transactionID:transactionID error:error];
}

- (long long int)insertNewTransactionIntoDatabase:(FMDatabase *)database error:(NSError **)error {
	NSParameterAssert(database != nil);

	BOOL success = [self insertIntoDatabase:database value:[NSDate date] forAttribute:FRZStoreTransactionDateAttribute key:@"head" transactionID:0 error:error];
	if (!success) return -1;

	return database.lastInsertRowId;
}

- (BOOL)addValue:(id<NSCoding>)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		BOOL isCollection = [self.store.databaseBeforeTransaction isCollectionAttribute:attribute];
		if (isCollection) {
			NSSet *existingValue = [self.store.databaseBeforeTransaction valueForKey:key attribute:attribute resolveReferences:NO] ?: [NSSet set];
			NSSet *newValue = [existingValue setByAddingObject:value];
			return [self insertIntoDatabase:database value:newValue forAttribute:attribute key:key transactionID:txID error:error];
		} else {
			BOOL success = [self insertIntoDatabase:database value:value forAttribute:attribute key:key transactionID:txID error:error];
			if (!success) return NO;
		}

		[self.store.queuedChanges addObject:[[FRZChange alloc] initWithType:FRZChangeTypeAdd key:key attribute:attribute delta:value]];

		return YES;
	}];
}

- (BOOL)updateHeadInDatabase:(FMDatabase *)database toID:(long long int)ID error:(NSError **)error {
	NSParameterAssert(database != nil);

	return [self insertIntoDatabase:database value:@(ID) forAttribute:FRZStoreHeadTransactionAttribute key:@"head" transactionID:0 error:error];
}

- (BOOL)addValuesWithKey:(NSString *)key error:(NSError **)error block:(BOOL (^)(FRZSingleKeyTransactor *transactor, NSError **error))block {
	NSParameterAssert(key != nil);
	NSParameterAssert(block != NULL);

	FRZSingleKeyTransactor *transactor = [[FRZSingleKeyTransactor alloc] initWithTransactor:self key:key];
	return [self performChangesWithError:error block:^(NSError **error) {
		return block(transactor, error);
	}];
}

- (BOOL)removeValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		FRZDatabase *previousDatabase = self.store.databaseBeforeTransaction;
		BOOL isCollection = [previousDatabase isCollectionAttribute:attribute];
		id currentValue = [previousDatabase valueForKey:key attribute:attribute resolveReferences:NO];
		
		BOOL validRemoval = NO;
		if (isCollection) {
			validRemoval = [currentValue containsObject:value];
		} else {
			validRemoval = [currentValue isEqual:value];
		}

		if (!validRemoval) {
			NSString *description = [NSString stringWithFormat:NSLocalizedString(@"Given value (%@) does not match current value (%@)", @""), value, currentValue];
			NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: description };
			if (error != NULL) *error = [NSError errorWithDomain:FRZErrorDomain code:FRZErrorInvalidValue userInfo:userInfo];
			return NO;
		}

		if (isCollection) {
			NSMutableSet *newSet = [currentValue mutableCopy];
			[newSet removeObject:value];
			id newValue;
			if (newSet.count < 1) {
				newValue = NSNull.null;
			} else {
				newValue = newSet;
			}

			BOOL success = [self insertIntoDatabase:database value:newValue forAttribute:attribute key:key transactionID:txID error:error];
			if (!success) return NO;
		} else {
			BOOL success = [self insertIntoDatabase:database value:NSNull.null forAttribute:attribute key:key transactionID:txID error:error];
			if (!success) return NO;
		}

		[self.store.queuedChanges addObject:[[FRZChange alloc] initWithType:FRZChangeTypeRemove key:key attribute:attribute delta:value]];

		return YES;
	}];
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

- (BOOL)trimOldKeys:(FMDatabase *)database error:(NSError **)error {
//	// 1. Get all the keys in the head of the database.
//	// 2. Delete any entries with a key not in that set.
//	FRZDatabase *currentDatabase = self.store.databaseBeforeTransaction;
//	NSArray *keys = currentDatabase.allKeys.allObjects;
//	for (NSString *attribute in currentDatabase.allAttributes) {
//		NSString *tableName = [self.store tableNameForAttribute:attribute];
//		NSString *query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE key NOT IN (%@)", tableName, [self placeholderWithCount:keys.count]];
//		BOOL success = [database executeUpdate:query withArgumentsInArray:keys];
//		if (!success) {
//			if (error != NULL) *error = database.lastError;
//			return NO;
//		}
//	}

	return YES;
}

- (BOOL)trimOldValues:(FMDatabase *)database error:(NSError **)error {
//	// 1. Get the IDs for all the latest values for the keys.
//	// 2. Delete any entries with an ID not in that set.
//	FRZDatabase *currentDatabase = self.store.databaseBeforeTransaction;
//	for (NSString *attribute in currentDatabase.allAttributes) {
//		NSString *query = [NSString stringWithFormat:@"SELECT id FROM %@ GROUP BY key ORDER BY tx_id DESC", tableName];
//		FMResultSet *set = [database executeQuery:@"SELECT id FROM %@ GROUP BY key ORDER BY tx_id DESC"];
//		if (set == nil) {
//			if (error != NULL) *error = database.lastError;
//			return NO;
//		}
//
//		NSMutableArray *IDs = [NSMutableArray array];
//		while ([set next]) {
//			id ID = [set objectForColumnIndex:0];
//			[IDs addObject:ID];
//		}
//
//		NSString *deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE id NOT IN (%@)", tableName, [self placeholderWithCount:IDs.count]];
//		BOOL success = [database executeUpdate:deleteQuery withArgumentsInArray:IDs];
//		if (!success) {
//			if (error != NULL) *error = database.lastError;
//			return NO;
//		}
//	}

	return YES;
}

- (BOOL)deleteEverythingButTheLastIDWithTableName:(NSString *)tableName database:(FMDatabase *)database error:(NSError **)error {
//	NSString *query = [NSString stringWithFormat:@"SELECT id FROM %@ ORDER BY id DESC LIMIT 1", tableName];
//	FMResultSet *set = [database executeQuery:query];
//	if (set == nil) {
//		if (error != NULL) *error = database.lastError;
//		return NO;
//	}
//
//	if (![set next]) return YES;
//
//	NSString *headID = [set objectForColumnIndex:0];
//	NSString *deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE id != ?", tableName];
//	BOOL success = [database executeUpdate:deleteQuery, headID];
//	if (!success) {
//		if (error != NULL) *error = database.lastError;
//		return NO;
//	}

	return YES;
}

- (BOOL)trimOldTransactions:(FMDatabase *)database error:(NSError **)error {
//	NSString *tableName = [self.store tableNameForAttribute:FRZStoreTransactionDateAttribute];
//	BOOL success = [self deleteEverythingButTheLastIDWithTableName:tableName database:database error:error];
//	if (!success) return NO;
//
//	tableName = [self.store tableNameForAttribute:FRZStoreHeadTransactionAttribute];
//	return [self deleteEverythingButTheLastIDWithTableName:tableName database:database error:error];
	return YES;
}

- (BOOL)trim:(NSError **)error {
	return [self.store performTransactionType:FRZStoreTransactionTypeExclusive withNewTransaction:NO error:error block:^(FMDatabase *database, long long txID, NSError **error) {
		BOOL success = [self trimOldKeys:database error:error];
		if (!success) return NO;

		success = [self trimOldValues:database error:error];
		if (!success) return NO;

		return [self trimOldTransactions:database error:error];
	}];
}

@end
