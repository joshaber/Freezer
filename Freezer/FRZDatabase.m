//
//  FRZDatabase.m
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZDatabase.h"
#import "FRZDatabase+Private.h"
#import "FMDatabase.h"
#import "FRZStore+Private.h"
#import "FRZTransactor+Private.h"

@interface FRZDatabase ()

@property (nonatomic, readonly, strong) FRZStore *store;

@property (nonatomic, readonly, assign) long long int headID;

@end

@implementation FRZDatabase

#pragma mark Lifecycle

- (id)initWithStore:(FRZStore *)store headID:(long long int)headID {
	NSParameterAssert(store != nil);

	self = [super init];
	if (self == nil) return nil;

	_store = store;
	_headID = headID;

	return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark Lookup

- (NSArray *)attributesInDatabase:(FMDatabase *)database error:(NSError **)error {
	NSParameterAssert(database != nil);

	FMResultSet *set = [database executeQuery:@"SELECT name FROM sqlite_master WHERE type = 'table' AND name != 'sqlite_sequence'"];
	if (set == nil) {
		if (error != NULL) *error = database.lastError;
		return nil;
	}

	NSMutableArray *names = [NSMutableArray array];
	while ([set next]) {
		[names addObject:[set objectForColumnIndex:0]];
	}

	return names;
}

- (id)valueForAttribute:(NSString *)attribute key:(NSString *)key inDatabase:(FMDatabase *)database success:(BOOL *)success error:(NSError **)error {
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);
	NSParameterAssert(database != nil);

	NSString *tableName = [self.store tableNameForAttribute:attribute];
	NSAssert(tableName != nil, @"Unknown table name for attribute: %@", attribute);

	NSString *query = [NSString stringWithFormat:@"SELECT value FROM %@ WHERE key = ? AND tx_id <= ? ORDER BY tx_id DESC LIMIT 1", tableName];
	FMResultSet *set = [database executeQuery:query, key, @(self.headID)];
	if (set == nil) {
		if (error != NULL) *error = database.lastError;
		if (success != NULL) *success = NO;
		return nil;
	}

	if (success != NULL) *success = YES;

	if (![set next]) return nil;

	id value = [set objectForColumnIndex:0];
	return [self unpackedValueFromValue:value];
}

- (NSDictionary *)objectForKeyedSubscript:(NSString *)key {
	NSParameterAssert(key != nil);

	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	[self.store performTransactionType:FRZStoreTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		NSArray *attributes = [self attributesInDatabase:database error:error];
		if (attributes == nil) return NO;

		for (NSString *attribute in attributes) {
			BOOL success = YES;
			id value = [self valueForAttribute:attribute key:key inDatabase:database success:&success error:error];
			if (value == nil && !success) return NO;
			if (value == nil) continue;

			result[attribute] = value;
		}

		return YES;
	}];

	return (result.count > 0 ? result : nil);
}

- (NSArray *)allKeys {
	NSMutableSet *results = [NSMutableSet set];
	[self.store performTransactionType:FRZStoreTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		NSArray *attributes = [self attributesInDatabase:database error:error];
		if (attributes == nil) return NO;

		for (NSString *attribute in attributes) {
			NSString *tableName = [self.store tableNameForAttribute:attribute];
			NSString *query = [NSString stringWithFormat:@"SELECT key, value FROM %@ WHERE tx_id <= ? ORDER BY tx_id DESC LIMIT 1", tableName];
			FMResultSet *set = [database executeQuery:query, @(self.headID)];
			if (set == nil) {
				if (error != NULL) *error = database.lastError;
				return NO;
			}

			if (![set next]) continue;

			id value = set[@"value"];
			if (value == NSNull.null) continue;

			id key = set[@"key"];
			[results addObject:key];
		}

		return YES;
	}];

	return results.allObjects;
}

- (NSArray *)keysWithAttribute:(NSString *)attribute {
	NSParameterAssert(attribute != nil);

	NSMutableArray *results = [NSMutableArray array];
	[self.store performTransactionType:FRZStoreTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		NSString *tableName = [self.store tableNameForAttribute:attribute];
		NSString *query = [NSString stringWithFormat:@"SELECT key, value FROM %@ WHERE tx_id <= ? GROUP BY key ORDER BY tx_id DESC", tableName];
		FMResultSet *set = [database executeQuery:query, @(self.headID)];
		if (set == nil) return NO;

		while ([set next]) {
			id value = set[@"value"];
			if (value == NSNull.null) continue;

			id key = set[@"key"];
			[results addObject:key];
		}

		return YES;
	}];

	return results;
}

- (id)valueForKey:(NSString *)key attribute:(NSString *)attribute {
	NSParameterAssert(key != nil);
	NSParameterAssert(attribute != nil);

	__block id result;
	[self.store performTransactionType:FRZStoreTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		BOOL success = NO;
		result = [self valueForAttribute:attribute key:key inDatabase:database success:&success error:error];
		return success;
	}];

	return result;
}

- (id)unpackedValueFromValue:(id)value {
	if (value == NSNull.null) return nil;

	return value;
}

@end
