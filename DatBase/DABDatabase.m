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
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	[self.coordinator performTransactionType:DABCoordinatorTransactionTypeDeferred error:NULL block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:@"SELECT * FROM entities WHERE key = ? GROUP BY attribute ORDER BY id DESC", key];
		if (set == nil) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		while ([set next]) {
			id value = [NSKeyedUnarchiver unarchiveObjectWithData:set[@"value"]];
			NSString *attribute = set[@"attribute"];
			result[attribute] = value;
		}

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
