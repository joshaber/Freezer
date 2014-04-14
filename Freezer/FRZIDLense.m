//
//  FRZIDLense.m
//  Freezer
//
//  Created by Josh Abernathy on 4/3/14.
//  Copyright (c) 2014 Josh Abernathy. All rights reserved.
//

#import "FRZIDLense+Private.h"
#import "FRZKeyLense+Private.h"
#import "FRZStore.h"
#import "FRZDatabase.h"
#import "FRZChange.h"

@interface FRZIDLense ()

@property (nonatomic, readonly, copy) NSString *ID;

@property (nonatomic, readonly, strong) FRZStore *store;

@property (nonatomic, readonly, copy) FRZDatabase *database;

@end

@implementation FRZIDLense

#pragma mark Lifecycle

- (id)initWithID:(NSString *)ID database:(FRZDatabase *)database store:(FRZStore *)store {
	NSParameterAssert(ID != nil);
	NSParameterAssert(database != nil);
	NSParameterAssert(store != nil);

	self = [super init];

	_ID = [ID copy];
	_database = [database copy];
	_store = store;
	_changes = [[store
		changes]
		filter:^(FRZChange *change) {
			return [change.ID isEqual:ID];
		}];

	return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark APIs

- (FRZKeyLense *)lenseWithKey:(NSString *)key {
	return [[FRZKeyLense alloc] initWithKey:key ID:self.ID database:self.database store:self.store];
}

@end
