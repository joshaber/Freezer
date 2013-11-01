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
	__block NSDictionary *result;
	[self.coordinator performTransactionType:DABCoordinatorTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@, %@ WHERE %@.tx_id = ? AND %@.entity_id = %@.id AND %@.key = ? LIMIT 1", DABEntitiesTableName, DABTransactionToEntityTableName, DABTransactionToEntityTableName, DABTransactionToEntityTableName, DABEntitiesTableName, DABEntitiesTableName];
		FMResultSet *set = [database executeQuery:query, @(self.transactionID), key];
		if (set == nil) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		if (![set next]) return YES;

		result = set.resultDictionary;

		return YES;
	}];

	return result;
}

- (NSArray *)allKeys {
	return @[];
//	NSArray *contents = self.commit.tree.contents;
//	NSMutableArray *keys = [NSMutableArray arrayWithCapacity:contents.count];
//	for (GTTreeEntry *entry in contents) {
//		[keys addObject:entry.name];
//	}
//
//	return keys;
}

@end
