//
//  FRZSingleKeyTransactor.m
//  Freezer
//
//  Created by Josh Abernathy on 11/8/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZSingleKeyTransactor.h"
#import "FRZSingleKeyTransactor+Private.h"
#import "FRZTransactor.h"

@interface FRZSingleKeyTransactor ()

@property (nonatomic, readonly, strong) FRZTransactor *transactor;

@property (nonatomic, readonly, copy) NSString *key;

@end

@implementation FRZSingleKeyTransactor

- (id)initWithTransactor:(FRZTransactor *)transactor key:(NSString *)key {
	NSParameterAssert(transactor != nil);
	NSParameterAssert(key != nil);

	self = [super init];
	if (self == nil) return nil;

	_transactor = transactor;
	_key = [key copy];

	return self;
}

- (BOOL)addValue:(id)value forAttribute:(NSString *)attribute error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);

	return [self.transactor addValue:value forAttribute:attribute key:self.key error:error];
}

@end
