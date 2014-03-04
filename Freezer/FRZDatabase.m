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
#import "FRZQuery+Private.h"
#import "FRZDeletedSentinel.h"

@interface FRZDatabase ()

@property (nonatomic, readonly, strong) NSCache *lookupCache;

@end

@implementation FRZDatabase

#pragma mark Lifecycle

- (id)initWithStore:(FRZStore *)store headID:(long long int)headID {
	NSParameterAssert(store != nil);

	self = [super init];
	if (self == nil) return nil;

	_store = store;
	_headID = headID;
	_lookupCache = [[NSCache alloc] init];
	_lookupCache.name = @"com.Freezer.FRZDatabase.lookupCache";

	return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark Lookup

- (NSSet *)allKeys {
	return [self IDsWithKey:FRZStoreKeyTypeKey];
}

- (id)singleValueForKey:(NSString *)key ID:(NSString *)ID resolveRef:(BOOL)resolveRef inDatabase:(FMDatabase *)database success:(BOOL *)success error:(NSError **)error {
	NSParameterAssert(key != nil);
	NSParameterAssert(ID != nil);
	NSParameterAssert(database != nil);

	FMResultSet *set = [database executeQuery:@"SELECT value FROM data WHERE frz_id = ? AND key = ? AND tx_id <= ? ORDER BY tx_id DESC LIMIT 1", ID, key, @(self.headID)];
	if (set == nil) {
		if (error != NULL) *error = database.lastError;
		if (success != NULL) *success = NO;
		return nil;
	}

	if (success != NULL) *success = YES;

	if (![set next]) return nil;

	id value = [self unpackedValueFromData:set[0]];
	if (value == FRZDeletedSentinel.deletedSentinel) return nil;

	return value;
}

- (id)valueForKey:(NSString *)key ID:(NSString *)ID inDatabase:(FMDatabase *)database resolveReferences:(BOOL)resolveReferences success:(BOOL *)success error:(NSError **)error {
	NSParameterAssert(key != nil);
	NSParameterAssert(ID != nil);
	NSParameterAssert(database != nil);

	return [self singleValueForKey:key ID:ID resolveRef:resolveReferences inDatabase:database success:success error:error];
}

- (NSDictionary *)objectForKeyedSubscript:(NSString *)ID {
	NSParameterAssert(ID != nil);

	return [self valueForID:ID];
}

- (NSDictionary *)valuesForID:(NSString *)ID keys:(NSArray *)keys {
	NSParameterAssert(ID != nil);
	NSParameterAssert(keys != nil);

	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	[self.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		for (NSString *key in keys) {
			BOOL success = YES;
			id value = [self valueForKey:key ID:ID inDatabase:database resolveReferences:YES success:&success error:error];
			if (value == nil && !success) return NO;
			if (value == nil) continue;

			result[key] = value;
		}

		return YES;
	}];

	return (result.count > 0 ? result : nil);
}

- (id)valueForID:(NSString *)ID {
	NSParameterAssert(ID != nil);

	id cachedValue = [self.lookupCache objectForKey:ID];
	if (cachedValue != nil) return cachedValue;

	NSMutableDictionary *results = [NSMutableDictionary dictionary];
	BOOL success = [self.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT key, value FROM data WHERE frz_id = ? AND tx_id <= ? GROUP BY key ORDER BY tx_id DESC", ID, @(self.headID)];
		if (set == nil) return NO;

		while ([set next]) {
			NSData *data = set[1];
			id key = set[0];
			id value = [self unpackedValueFromData:data];
			if (value == FRZDeletedSentinel.deletedSentinel) continue;

			results[key] = value;
		}

		return YES;
	}];

	if (!success) return nil;
	if (results.count < 1) return nil;

	if (results != nil) {
		[self.lookupCache setObject:results forKey:ID];
	}

	return results;
}

- (NSSet *)allIDs {
	NSMutableSet *results = [NSMutableSet set];
	[self.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT frz_id, value FROM data WHERE tx_id <= ? GROUP BY frz_id ORDER BY tx_id DESC", @(self.headID)];
		if (set == nil) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		while ([set next]) {
			NSData *data = set[1];
			id value = [self unpackedValueFromData:data];
			if (value == FRZDeletedSentinel.deletedSentinel) continue;

			id key = set[0];
			[results addObject:key];
		}

		return YES;
	}];

	return results;
}

- (NSSet *)IDsWithKey:(NSString *)key {
	NSParameterAssert(key != nil);

	NSMutableSet *results = [NSMutableSet set];
	[self.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT frz_id, value FROM data WHERE key = ? AND tx_id <= ? GROUP BY frz_id ORDER BY tx_id DESC", key, @(self.headID)];
		if (set == nil) return NO;

		while ([set next]) {
			NSData *data = set[1];
			id value = [self unpackedValueFromData:data];
			if (value == FRZDeletedSentinel.deletedSentinel) continue;

			id key = set[0];
			[results addObject:key];
		}

		return YES;
	}];

	return results;
}

- (id)valueForID:(NSString *)ID key:(NSString *)key {
	NSParameterAssert(ID != nil);
	NSParameterAssert(key != nil);

	return [self valueForID:ID key:key resolveReferences:YES];
}

- (id)valueForID:(NSString *)ID key:(NSString *)key resolveReferences:(BOOL)resolveReferences {
	NSParameterAssert(ID != nil);
	NSParameterAssert(key != nil);

	NSString *cacheKey = [NSString stringWithFormat:@"%@-%@-%d", ID, key, resolveReferences];
	id cachedValue = [self.lookupCache objectForKey:cacheKey];
	if (cachedValue != nil) return cachedValue;

	__block id result;
	[self.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		BOOL success = NO;
		result = [self valueForKey:key ID:ID inDatabase:database resolveReferences:resolveReferences success:&success error:error];
		return success;
	}];

	if (result != nil) {
		[self.lookupCache setObject:result forKey:cacheKey];
	}

	return result;
}

- (id)unpackedValueFromData:(NSData *)data {
	NSParameterAssert(data != nil);

	return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

- (FRZQuery *)query {
	return [[FRZQuery alloc] initWithDatabase:self];
}

@end
