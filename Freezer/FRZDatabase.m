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
#import "FRZCoordinator+Private.h"
#import "FRZTransactor+Private.h"

@interface FRZDatabase ()

@property (nonatomic, readonly, strong) FRZCoordinator *coordinator;

@property (nonatomic, readonly, assign) long long int transactionID;

@end

@implementation FRZDatabase

- (id)initWithCoordinator:(FRZCoordinator *)coordinator transactionID:(long long int)transactionID {
	NSParameterAssert(coordinator != nil);

	self = [super init];
	if (self == nil) return nil;

	_coordinator = coordinator;
	_transactionID = transactionID;

	return self;
}

- (NSDictionary *)objectForKeyedSubscript:(NSString *)key {
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	[self.coordinator performTransactionType:FRZCoordinatorTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		// NB: We don't want to filter out NULL values, because otherwise we'd
		// inherit the last non-null value, which effectively ignores deletions.
		FMResultSet *set = [database executeQuery:@"SELECT attribute, value FROM entities WHERE key = ? AND tx_id <= ? GROUP BY attribute ORDER BY id DESC", key, @(self.transactionID)];
		if (set == nil) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		// TODO: Do we have to do this within the transaction?
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
	[self.coordinator performTransactionType:FRZCoordinatorTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT DISTINCT key FROM entities WHERE value IS NOT NULL AND tx_id <= ? GROUP BY attribute ORDER BY id DESC", @(self.transactionID)];
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
	NSMutableArray *results = [NSMutableArray array];
	[self.coordinator performTransactionType:FRZCoordinatorTransactionTypeDeferred error:error block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT key FROM entities WHERE attribute = ? AND value IS NOT NULL AND tx_id <= ? ORDER BY id DESC", attribute, @(self.transactionID)];
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
