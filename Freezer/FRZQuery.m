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

@property (nonatomic, readonly, copy) BOOL (^filter)(NSString *, NSString *, id);

@property (nonatomic, readonly, assign) NSUInteger take;

@property (atomic, copy) NSSet *results;

@end

@implementation FRZQuery

#pragma mark Lifecycle

- (id)initWithDatabase:(FRZDatabase *)database {
	NSParameterAssert(database != nil);

	self = [super init];
	if (self == nil) return nil;

	_database = database;

	return self;
}

- (id)initWithDatabase:(FRZDatabase *)database filter:(BOOL (^)(NSString *key, NSString *attribute, id value))filter take:(NSUInteger)take {
	self = [self initWithDatabase:database];
	if (self == nil) return nil;

	_filter = [filter copy];
	_take = take;

	return self;
}

#pragma mark Querying

- (instancetype)filter:(BOOL (^)(NSString *key, NSString *attribute, id value))filter {
	NSParameterAssert(filter != NULL);

	return [[self.class alloc] initWithDatabase:self.database filter:filter take:self.take];
}

- (instancetype)take:(NSUInteger)take {
	return [[self.class alloc] initWithDatabase:self.database filter:self.filter take:take];
}

void FRZQueryFilterCallback(sqlite3_context *context, int argc, sqlite3_value **argv) {
	void (^block)(sqlite3_context *context, int argc, sqlite3_value **argv) = (__bridge id)sqlite3_user_data(context);
	if (block != NULL) block(context, argc, argv);
};

void FRZQueryFilterCleanup(void *context) {
	if (context != NULL) CFRelease(context);
}

- (BOOL)withFilterFunction:(BOOL (^)(NSString *functionName))block {
	if (self.filter == NULL) return block(nil);

	FMDatabase *database = [self.database.store databaseForCurrentThread:NULL];
	id intermediateBlock = ^(sqlite3_context *context, int argc, sqlite3_value **argv) {
		NSData *keyData = [NSData dataWithBytes:sqlite3_value_blob(argv[0]) length:sqlite3_value_bytes(argv[0])];
		NSString *key = [[NSString alloc] initWithData:keyData encoding:NSUTF8StringEncoding];

		NSData *attributeData = [NSData dataWithBytes:sqlite3_value_blob(argv[1]) length:sqlite3_value_bytes(argv[1])];
		NSString *attribute = [[NSString alloc] initWithData:attributeData encoding:NSUTF8StringEncoding];

		NSData *valueData = [NSData dataWithBytes:sqlite3_value_blob(argv[2]) length:sqlite3_value_bytes(argv[2])];
		id value = [NSKeyedUnarchiver unarchiveObjectWithData:valueData];

		BOOL result = self.filter(key, attribute, value);
		sqlite3_result_int(context, result);
	};

	NSString *UUID = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
	NSString *functionName = [@"FRZQueryFilter" stringByAppendingString:UUID];

	sqlite3_create_function_v2(database.sqliteHandle, functionName.UTF8String, 3, SQLITE_UTF8, (void *)CFBridgingRetain([intermediateBlock copy]), &FRZQueryFilterCallback, NULL, NULL, &FRZQueryFilterCleanup);

	BOOL success = block(functionName);

	sqlite3_create_function_v2(database.sqliteHandle, functionName.UTF8String, 3, SQLITE_UTF8, NULL, NULL, NULL, NULL, NULL);

	return success;
}

- (NSString *)buildQueryWithFilterFunctionName:(NSString *)filterFunctionName {
	NSString *filterString = (filterFunctionName.length > 0 ? [NSString stringWithFormat:@"AND %@(key, attribute, value)", filterFunctionName] : @"");
	NSString *takeString = (self.take > 0 ? [NSString stringWithFormat:@"LIMIT %lu", (unsigned long)self.take] : @"");
	NSString *baseQueryTemplate = @"SELECT key FROM data WHERE tx_id <= ? %@ GROUP BY key ORDER BY tx_id DESC %@";
	return [NSString stringWithFormat:baseQueryTemplate, filterString, takeString];
}

- (NSSet *)allKeys {
	if (self.results != nil) return self.results;

	NSMutableSet *keys = [NSMutableSet set];
	BOOL success = [self.database.store performReadTransactionWithError:NULL block:^(FMDatabase *database, NSError **error) {
		return [self withFilterFunction:^(NSString *functionName) {
			NSString *query = [self buildQueryWithFilterFunctionName:functionName];
			FMResultSet *set = [database executeQuery:query, @(self.database.headID)];
			if (set == nil) return NO;

			while ([set next]) {
				NSString *key = [set stringForColumnIndex:0];
				[keys addObject:key];
			}

			return YES;
		}];
	}];

	if (!success) return nil;

	self.results = keys;

	return self.results;
}

@end
