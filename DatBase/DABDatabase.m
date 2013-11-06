//
//  DABDatabase.m
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABDatabase.h"
#import "DABDatabase+Private.h"
#import "FMDatabase.h"
#import "DABCoordinator+Private.h"
#import "DABTransactor+Private.h"

@interface DABDatabase ()

@property (nonatomic, readonly, strong) DABCoordinator *coordinator;

@property (nonatomic, readonly, assign) long long int transactionID;

@end

@implementation DABDatabase

- (id)initWithCoordinator:(DABCoordinator *)coordinator transactionID:(long long int)transactionID {
	NSParameterAssert(coordinator != nil);

	self = [super init];
	if (self == nil) return nil;

	_coordinator = coordinator;
	_transactionID = transactionID;

	return self;
}

- (NSDictionary *)objectForKeyedSubscript:(NSString *)key {
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	[self.coordinator performTransactionType:DABCoordinatorTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT attribute, value FROM entities WHERE key = ? AND tx_id <= ? GROUP BY attribute ORDER BY id DESC", key, @(self.transactionID)];
		if (set == nil) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		// TODO: Do we have to do this within the transaction?
		while ([set next]) {
			NSData *valueData = set[@"value"];
			if ([valueData isEqual:DABTransactor.deletedSentinel]) continue;

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
	[self.coordinator performTransactionType:DABCoordinatorTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT DISTINCT key FROM entities WHERE tx_id <= ? GROUP BY attribute ORDER BY id DESC", @(self.transactionID)];
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
