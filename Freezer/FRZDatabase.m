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

- (NSDictionary *)objectForKeyedSubscript:(NSString *)key {
	NSParameterAssert(key != nil);

	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	[self.store performTransactionType:FRZStoreTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		// NB: We don't want to filter out NULL values, because otherwise we'd
		// inherit the last non-null value, which effectively ignores deletions.
		FMResultSet *set = [database executeQuery:@"SELECT attribute, value FROM entities WHERE key = ? AND tx_id <= ? GROUP BY attribute ORDER BY id DESC", key, @(self.headID)];
		if (set == nil) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		// TODO: Can we do this outside the transaction?
		while ([set next]) {
			id valueData = set[@"value"];
			if (valueData == NSNull.null) continue;

			id value = [NSKeyedUnarchiver unarchiveObjectWithData:valueData];
			NSString *attribute = set[@"attribute"];
			result[attribute] = value;
		}

		return YES;
	}];

	return result;
}

- (NSArray *)allKeys {
	NSMutableArray *results = [NSMutableArray array];
	[self.store performTransactionType:FRZStoreTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT DISTINCT key FROM entities WHERE value IS NOT NULL AND tx_id <= ? GROUP BY attribute ORDER BY id DESC", @(self.headID)];
		if (set == nil) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		while ([set next]) {
			[results addObject:[set objectForColumnIndex:0]];
		}

		return YES;
	}];

	return results;
}

- (NSArray *)keysWithAttribute:(NSString *)attribute error:(NSError **)error {
	NSParameterAssert(attribute != nil);

	NSMutableArray *results = [NSMutableArray array];
	[self.store performTransactionType:FRZStoreTransactionTypeDeferred error:error block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT key FROM entities WHERE attribute = ? AND value IS NOT NULL AND tx_id <= ? ORDER BY id DESC", attribute, @(self.headID)];
		if (set == nil) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		while ([set next]) {
			[results addObject:[set objectForColumnIndex:0]];
		}

		return YES;
	}];

	return results;
}

@end
