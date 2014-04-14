//
//  FRZKeyLense.m
//  Freezer
//
//  Created by Josh Abernathy on 4/3/14.
//  Copyright (c) 2014 Josh Abernathy. All rights reserved.
//

#import "FRZKeyLense+Private.h"
#import "FRZIDLense+Private.h"
#import "FRZDatabase.h"
#import "FRZStore.h"
#import "FRZChange.h"
#import "FRZTransactor.h"

@interface FRZKeyLense ()

@property (nonatomic, readonly, copy) FRZDatabase *database;

@property (nonatomic, readonly, strong) FRZStore *store;

@property (nonatomic, readonly, copy) NSString *key;

@property (nonatomic, readonly, copy) NSString *ID;

@end

@implementation FRZKeyLense

#pragma mark Lifecycle

- (id)initWithKey:(NSString *)key ID:(NSString *)ID database:(FRZDatabase *)database store:(FRZStore *)store {
	NSParameterAssert(key != nil);
	NSParameterAssert(ID != nil);
	NSParameterAssert(database != nil);
	NSParameterAssert(store != nil);

	self = [super init];

	_key = [key copy];
	_ID = [ID copy];
	_database = [database copy];
	_store = store;
	_changes = [[store
		changes]
		filter:^ BOOL (FRZChange *change) {
			return [change.ID isEqual:ID] && [change.key isEqual:key];
		}];
	_value = [database[ID][key] copy];

	return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark Mutation

- (FRZKeyLense *)addValue:(id)value error:(NSError **)error {
	FRZTransactor *transactor = [self.store transactor];
	BOOL success = [transactor addValue:value forKey:self.key ID:self.ID error:error];
	if (!success) return nil;

	return [[FRZKeyLense alloc] initWithKey:self.key ID:self.ID database:[self.store currentDatabase] store:self.store];
}

- (FRZKeyLense *)pushValue:(id)value error:(NSError **)error {
	FRZTransactor *transactor = [self.store transactor];
	BOOL success = [transactor pushValue:value forKey:self.key ID:self.ID error:error];
	if (!success) return nil;

	return [[FRZKeyLense alloc] initWithKey:self.key ID:self.ID database:[self.store currentDatabase] store:self.store];
}

- (FRZKeyLense *)remove:(NSError **)error {
	FRZTransactor *transactor = [self.store transactor];
	BOOL success = [transactor removeValueForKey:self.key ID:self.ID error:error];
	if (!success) return nil;

	return [[FRZKeyLense alloc] initWithKey:self.key ID:self.ID database:[self.store currentDatabase] store:self.store];
}

- (FRZKeyLense *)removeValue:(id)value error:(NSError **)error {
	FRZTransactor *transactor = [self.store transactor];
	BOOL success = [transactor removeValue:value forKey:self.key ID:self.ID error:error];
	if (!success) return nil;

	return [[FRZKeyLense alloc] initWithKey:self.key ID:self.ID database:[self.store currentDatabase] store:self.store];
}

- (FRZIDLense *)lenseWithID {
	return [[FRZIDLense alloc] initWithID:self.value database:self.database store:self.store];
}

/// Create an array of `FRZIDLense`s for each ID in `value`.
- (NSSet *)lensesWithIDs {
	NSSet *values = self.value;
	NSMutableSet *lenses = [NSMutableSet setWithCapacity:values.count];
	for (NSString *ID in values) {
		FRZIDLense *lense = [[FRZIDLense alloc] initWithID:ID database:self.database store:self.store];
		[lenses addObject:lense];
	}

	return lenses;
}

@end
