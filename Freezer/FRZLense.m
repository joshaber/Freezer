//
//  FRZLense.m
//  Freezer
//
//  Created by Josh Abernathy on 4/13/14.
//  Copyright (c) 2014 Josh Abernathy. All rights reserved.
//

#import "FRZLense+Private.h"
#import "FRZDatabase.h"
#import "FRZTransactor.h"
#import "FRZStore.h"

@interface FRZLense ()

@property (nonatomic, readonly, copy) FRZDatabase *database;

@property (nonatomic, readonly, strong) FRZStore *store;

@property (nonatomic, readonly, copy) id (^removeBlock)(id, FRZTransactor *, NSError **);

@property (nonatomic, readonly, copy) id (^addBlock)(id, FRZTransactor *, NSError **);

@property (nonatomic, readonly, copy) id (^readBlock)(FRZDatabase *, NSError **);

@end

@implementation FRZLense

#pragma mark Lifecycle

- (id)initWithDatabase:(FRZDatabase *)database store:(FRZStore *)store removeBlock:(id (^)(id, FRZTransactor *, NSError **))removeBlock addBlock:(id (^)(id, FRZTransactor *, NSError **))addBlock readBlock:(id (^)(FRZDatabase *, NSError **))readBlock {
	NSParameterAssert(database != nil);
	NSParameterAssert(store != nil);

	self = [super init];
	if (self == nil) return nil;

	_database = [database copy];
	_store = store;

	_removeBlock = [removeBlock copy];
	_addBlock = [addBlock copy];
	_readBlock = [readBlock copy];

	return self;
}

#pragma mark Access

- (id)add:(id<NSCopying>)value error:(NSError **)error {
	NSParameterAssert(self.addBlock != NULL);

	return self.addBlock(value, [self.store transactor], error);
}

- (id)remove:(NSError **)error {
	NSParameterAssert(self.removeBlock != NULL);

	return self.removeBlock(nil, [self.store transactor], error);
}

- (id)remove:(id)value error:(NSError **)error {
	NSParameterAssert(self.removeBlock != NULL);

	return self.removeBlock(value, [self.store transactor], error);
}

- (id)value {
	NSParameterAssert(self.readBlock != NULL);

	NSError *error;
	return self.readBlock(self.database, &error);
}

- (FRZLense *)compose:(FRZLense *)lense {
	return [[FRZLense alloc] initWithDatabase:self.database store:self.store removeBlock:^(id value, FRZTransactor *transactor, NSError **error) {
		return self.removeBlock(lense.removeBlock(value, transactor, error), transactor, error);
	} addBlock:^(id value, FRZTransactor *transactor, NSError **error) {
		return self.addBlock(lense.addBlock(value, transactor, error), transactor, error);
	} readBlock:^(FRZDatabase *database, NSError **error) {
		NSDictionary *x = lense.readBlock(database, error);
		id y = self.readBlock(database, error);
		return x[y];
	}];
}

@end
