//
//  FRZSingleIDTransactor.m
//  Freezer
//
//  Created by Josh Abernathy on 11/8/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZSingleIDTransactor.h"
#import "FRZSingleIDTransactor+Private.h"
#import "FRZTransactor.h"

@interface FRZSingleIDTransactor ()

@property (nonatomic, readonly, strong) FRZTransactor *transactor;

@property (nonatomic, readonly, copy) NSString *ID;

@end

@implementation FRZSingleIDTransactor

#pragma mark Lifecycle

- (id)initWithTransactor:(FRZTransactor *)transactor ID:(NSString *)ID {
	NSParameterAssert(transactor != nil);
	NSParameterAssert(ID != nil);

	self = [super init];
	if (self == nil) return nil;

	_transactor = transactor;
	_ID = [ID copy];

	return self;
}

#pragma mark Adding

- (BOOL)addValue:(id<NSCoding>)value forKey:(NSString *)key error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(key != nil);

	return [self.transactor addValue:value forKey:key ID:self.ID error:error];
}

@end
