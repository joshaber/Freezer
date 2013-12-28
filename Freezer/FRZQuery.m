//
//  FRZQuery.m
//  Freezer
//
//  Created by Josh Abernathy on 12/27/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZQuery+Private.h"
#import "FRZDatabase+Private.h"
#import "FRZStore+Private.h"
#import "FMDatabase.h"

@interface FRZQuery ()

@property (nonatomic, readonly, strong) FRZDatabase *database;

@property (nonatomic, readonly, copy) NSString * (^queryStringBlock)(void);

@end

@implementation FRZQuery

#pragma mark Lifecycle

- (id)initWithDatabase:(FRZDatabase *)database queryStringBlock:(NSString * (^)(void))queryStringBlock {
	NSParameterAssert(database != nil);

	self = [super init];
	if (self == nil) return nil;

	_database = database;
	_queryStringBlock = [queryStringBlock copy];

	return self;
}

#pragma mark Querying

void FRZQueryCallback(sqlite3_context *context, int argc, sqlite3_value **argv) {
	void (^block)(sqlite3_context *context, int argc, sqlite3_value **argv) = (__bridge id)sqlite3_user_data(context);
	if (block != NULL) block(context, argc, argv);
};

- (FRZQuery *)filter:(BOOL (^)(NSString *key, NSString *attribute, id value))block {
	NSString *functionName = @"urmom";//[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
	[self.database.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		id intermediateBlock = ^(sqlite3_context *context, int argc, sqlite3_value **argv) {
			NSData *keyData = [NSData dataWithBytes:sqlite3_value_blob(argv[0]) length:sqlite3_value_bytes(argv[0])];
			NSString *key = [[NSString alloc] initWithData:keyData encoding:NSUTF8StringEncoding];

			NSData *attributeData = [NSData dataWithBytes:sqlite3_value_blob(argv[1]) length:sqlite3_value_bytes(argv[1])];
			NSString *attribute = [[NSString alloc] initWithData:attributeData encoding:NSUTF8StringEncoding];

			NSData *valueData = [NSData dataWithBytes:sqlite3_value_blob(argv[2]) length:sqlite3_value_bytes(argv[2])];
			id value = [NSKeyedUnarchiver unarchiveObjectWithData:valueData];

			BOOL result = block(key, attribute, value);
			sqlite3_result_int(context, result);
		};
		sqlite3_create_function(database.sqliteHandle, functionName.UTF8String, -1, SQLITE_UTF8, (void *)CFBridgingRetain([intermediateBlock copy]), &FRZQueryCallback, NULL, NULL);
		return YES;
	}];

	return [[self.class alloc] initWithDatabase:self.database queryStringBlock:^{
		return [NSString stringWithFormat:@"%@(key, attribute, value)", functionName];
	}];
}

- (NSArray *)allKeys {
	NSMutableArray *keys = [NSMutableArray array];
	BOOL success = [self.database.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		NSString *query = [NSString stringWithFormat:@"SELECT key FROM data WHERE tx_id <= ? AND %@ GROUP BY attribute ORDER BY tx_id DESC", self.queryStringBlock()];
		FMResultSet *set = [database executeQuery:query, @(self.database.headID)];
		if (set == nil) return NO;

		while ([set next]) {
			[keys addObject:set[0]];
		}

		return YES;
	}];

	if (!success) return nil;

	return keys;
}

@end
