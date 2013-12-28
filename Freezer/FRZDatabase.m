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

- (NSSet *)allAttributes {
	return [self keysWithAttribute:FRZStoreAttributeTypeAttribute];
}

- (id)singleValueForAttribute:(NSString *)attribute key:(NSString *)key resolveRef:(BOOL)resolveRef inDatabase:(FMDatabase *)database success:(BOOL *)success error:(NSError **)error {
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);
	NSParameterAssert(database != nil);

	FMResultSet *set = [database executeQuery:@"SELECT value FROM data WHERE key = ? AND attribute = ? AND tx_id <= ? ORDER BY tx_id DESC LIMIT 1", key, attribute, @(self.headID)];
	if (set == nil) {
		if (error != NULL) *error = database.lastError;
		if (success != NULL) *success = NO;
		return nil;
	}

	if (success != NULL) *success = YES;

	if (![set next]) return nil;

	FRZAttributeType type = [self typeForAttribute:attribute];
	id value = [self unpackedValueFromData:set[0] type:type resolveRef:resolveRef];
	if (value == NSNull.null) return nil;

	return value;
}

- (id)valueForAttribute:(NSString *)attribute key:(NSString *)key inDatabase:(FMDatabase *)database resolveReferences:(BOOL)resolveReferences success:(BOOL *)success error:(NSError **)error {
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);
	NSParameterAssert(database != nil);

	return [self singleValueForAttribute:attribute key:key resolveRef:resolveReferences inDatabase:database success:success error:error];
}

- (NSDictionary *)objectForKeyedSubscript:(NSString *)key {
	NSParameterAssert(key != nil);

	return [self valueForKey:key];
}

- (NSDictionary *)valuesForKey:(NSString *)key attributes:(NSArray *)attributes {
	NSParameterAssert(key != nil);
	NSParameterAssert(attributes != nil);

	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	[self.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		for (NSString *attribute in attributes) {
			BOOL success = YES;
			id value = [self valueForAttribute:attribute key:key inDatabase:database resolveReferences:YES success:&success error:error];
			if (value == nil && !success) return NO;
			if (value == nil) continue;

			result[attribute] = value;
		}

		return YES;
	}];

	return (result.count > 0 ? result : nil);
}

- (id)valueForKey:(NSString *)key {
	NSParameterAssert(key != nil);

	id cachedValue = [self.lookupCache objectForKey:key];
	if (cachedValue != nil) return cachedValue;

	NSMutableDictionary *results = [NSMutableDictionary dictionary];
	BOOL success = [self.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT attribute, value FROM data WHERE key = ? AND tx_id <= ? GROUP BY attribute ORDER BY tx_id DESC", key, @(self.headID)];
		if (set == nil) return NO;

		while ([set next]) {
			NSData *data = set[1];
			id attribute = set[0];
			FRZAttributeType type = [self typeForAttribute:attribute];
			id value = [self unpackedValueFromData:data type:type resolveRef:YES];
			if (value == NSNull.null) continue;

			results[attribute] = value;
		}

		return YES;
	}];

	if (!success) return nil;
	if (results.count < 1) return nil;

	if (results != nil) {
		[self.lookupCache setObject:results forKey:key];
	}

	return results;
}

- (NSSet *)allKeys {
	NSMutableSet *results = [NSMutableSet set];
	[self.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		for (NSString *attribute in self.allAttributes) {
			FMResultSet *set = [database executeQuery:@"SELECT key, value FROM data WHERE tx_id <= ? GROUP BY key ORDER BY tx_id DESC", @(self.headID)];
			if (set == nil) {
				if (error != NULL) *error = database.lastError;
				return NO;
			}

			while ([set next]) {
				NSData *data = set[1];
				id value = [self unpackedValueFromData:data type:FRZAttributeTypeBlob resolveRef:NO];
				if (value == NSNull.null) continue;

				id key = set[0];
				[results addObject:key];
			}
		}

		return YES;
	}];

	return results;
}

- (NSSet *)keysWithAttribute:(NSString *)attribute {
	NSParameterAssert(attribute != nil);

	NSMutableSet *results = [NSMutableSet set];
	[self.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT key, value FROM data WHERE attribute = ? AND tx_id <= ? GROUP BY key ORDER BY tx_id DESC", attribute, @(self.headID)];
		if (set == nil) return NO;

		while ([set next]) {
			NSData *data = set[1];
			id value = [self unpackedValueFromData:data type:FRZAttributeTypeBlob resolveRef:NO];
			if (value == NSNull.null) continue;

			id key = set[0];
			[results addObject:key];
		}

		return YES;
	}];

	return results;
}

- (id)valueForKey:(NSString *)key attribute:(NSString *)attribute {
	NSParameterAssert(key != nil);
	NSParameterAssert(attribute != nil);

	return [self valueForKey:key attribute:attribute resolveReferences:YES];
}

- (id)valueForKey:(NSString *)key attribute:(NSString *)attribute resolveReferences:(BOOL)resolveReferences {
	NSParameterAssert(key != nil);
	NSParameterAssert(attribute != nil);

	NSString *cacheKey = [NSString stringWithFormat:@"%@-%@-%d", key, attribute, resolveReferences];
	id cachedValue = [self.lookupCache objectForKey:cacheKey];
	if (cachedValue != nil) return cachedValue;

	__block id result;
	[self.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		BOOL success = NO;
		result = [self valueForAttribute:attribute key:key inDatabase:database resolveReferences:resolveReferences success:&success error:error];
		return success;
	}];

	if (result != nil) {
		[self.lookupCache setObject:result forKey:cacheKey];
	}

	return result;
}

- (NSArray *)defaultAttributes {
	return @[
		FRZStoreAttributeTypeAttribute,
		FRZStoreAttributeIsCollectionAttribute,
	];
}

- (BOOL)isCollectionAttribute:(NSString *)attribute {
	NSParameterAssert(attribute != nil);

	if ([self.defaultAttributes containsObject:attribute]) return NO;

	return [[self valueForKey:attribute attribute:FRZStoreAttributeIsCollectionAttribute] boolValue];
}

- (FRZAttributeType)typeForAttribute:(NSString *)attribute {
	NSParameterAssert(attribute != nil);

	if ([self.defaultAttributes containsObject:attribute]) return 0;

	return [[self valueForKey:attribute attribute:FRZStoreAttributeTypeAttribute] integerValue];
}

- (id)unpackedValueFromData:(NSData *)data type:(FRZAttributeType)type resolveRef:(BOOL)resolveRef {
	NSParameterAssert(data != nil);

	id value = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	if (type == FRZAttributeTypeRef && resolveRef) {
		return self[value];
	}

	return value;
}

@end
