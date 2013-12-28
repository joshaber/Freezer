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

@property (nonatomic, readonly, copy) NSString *filterFunctionName;

@end

@implementation FRZQuery

#pragma mark Lifecycle

- (void)dealloc {
	// TODO: This is problematic because it requires that the query be
	// deallocated on the same thread on which the function was created.
	FMDatabase *database = [self.database.store databaseForCurrentThread:NULL];
	sqlite3_create_function_v2(database.sqliteHandle, self.filterFunctionName.UTF8String, -1, SQLITE_UTF8, NULL, NULL, NULL, NULL, NULL);
}

- (id)initWithDatabase:(FRZDatabase *)database {
	NSParameterAssert(database != nil);

	self = [super init];
	if (self == nil) return nil;

	_database = database;

	NSString *UUID = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
	_filterFunctionName = [@"FRZQueryFilter" stringByAppendingString:UUID];

	return self;
}

#pragma mark Querying

void FRZQueryFilterCallback(sqlite3_context *context, int argc, sqlite3_value **argv) {
	void (^block)(sqlite3_context *context, int argc, sqlite3_value **argv) = (__bridge id)sqlite3_user_data(context);
	if (block != NULL) block(context, argc, argv);
};

void FRZQueryFilterCleanup(void *context) {
	CFBridgingRelease(context);
}

- (void)setFilter:(BOOL (^)(NSString *key, NSString *attribute, id value))block {
	_filter = [block copy];

	// TODO: This is problematic because the function will only be available to
	// this database.
	FMDatabase *database = [self.database.store databaseForCurrentThread:NULL];
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

	sqlite3_create_function_v2(database.sqliteHandle, self.filterFunctionName.UTF8String, -1, SQLITE_UTF8, (void *)CFBridgingRetain([intermediateBlock copy]), &FRZQueryFilterCallback, NULL, NULL, &FRZQueryFilterCleanup);
}

- (NSString *)buildQuery {
	NSString *filterString = (self.filterFunctionName.length > 0 ? [NSString stringWithFormat:@"AND %@(key, attribute, value)", self.filterFunctionName] : @"");
	NSString *takeString = (self.take > 0 ? [NSString stringWithFormat:@"LIMIT %lu", self.take] : @"");
	NSString *baseQueryTemplate = @"SELECT key FROM data WHERE tx_id <= ? %@ GROUP BY attribute ORDER BY tx_id DESC %@";
	return [NSString stringWithFormat:baseQueryTemplate, filterString, takeString];
}

- (NSArray *)allKeys {
	NSMutableArray *keys = [NSMutableArray array];
	BOOL success = [self.database.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		FMResultSet *set = [database executeQuery:[self buildQuery], @(self.database.headID)];
		if (set == nil) return NO;

		while ([set next]) {
			NSString *key = set[0];
			[keys addObject:key];
		}

		return YES;
	}];

	if (!success) return nil;

	return keys;
}

@end
