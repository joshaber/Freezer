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
#import "DABDatabasePool.h"
#import "DABCoordinator+Private.h"

@interface DABDatabase ()

@property (nonatomic, readonly, strong) DABDatabasePool *databasePool;

@property (nonatomic, readonly, assign) long long int transactionID;

@end

@implementation DABDatabase

- (id)initWithDatabasePool:(DABDatabasePool *)databasePool transactionID:(long long int)transactionID {
	NSParameterAssert(databasePool != nil);

	self = [super init];
	if (self == nil) return nil;

	_databasePool = databasePool;
	_transactionID = transactionID;

	return self;
}

- (NSDictionary *)objectForKeyedSubscript:(NSString *)key {
//	FMDatabase *database = [self.databasePool databaseForCurrentThread:NULL];
//	FMResultSet *set = [database executeQuery:@"SELECT * FROM ? WHERE tx_id <= ? ORDER BY tx_id DESC LIMIT 1", DABEntitiesTableName, @(self.transactionID)];
//
//	GTTreeEntry *entry = [self.commit.tree entryWithName:key];
//	GTBlob *blob = (GTBlob *)[entry toObjectAndReturnError:NULL];
//	if (blob == nil) return nil;
//
//	return [NSJSONSerialization JSONObjectWithData:blob.data options:0 error:NULL];
	return @{};
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
