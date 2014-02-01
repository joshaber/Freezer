//
//  FRZChange.m
//  Freezer
//
//  Created by Josh Abernathy on 11/6/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZChange.h"
#import "FRZChange+Private.h"
#import "FRZDatabase.h"

@implementation FRZChange

#pragma mark Lifecycle

- (id)initWithType:(FRZChangeType)type ID:(NSString *)ID key:(NSString *)key delta:(id)delta previousDatabase:(FRZDatabase *)previousDatabase changedDatabase:(FRZDatabase *)changedDatabase {
	NSParameterAssert(changedDatabase != nil);

	self = [self initWithType:type ID:ID key:key delta:delta];
	if (self == nil) return nil;

	_previousDatabase = previousDatabase;
	_changedDatabase = changedDatabase;

	return self;
}

- (id)initWithType:(FRZChangeType)type ID:(NSString *)ID key:(NSString *)key delta:(id)delta {
	NSParameterAssert(ID != nil);
	NSParameterAssert(key != nil);
	NSParameterAssert(delta != nil);

	self = [super init];
	if (self == nil) return nil;

	_type = type;
	_ID = [ID copy];
	_key = [key copy];
	_delta = delta;

	return self;
}

#pragma mark NSObject

- (NSString *)description {
	NSDictionary *typeToTypeName = @{
		@(FRZChangeTypeAdd): @"add",
		@(FRZChangeTypeRemove): @"remove",
	};
	NSString *typeName = typeToTypeName[@(self.type)];

	return [NSString stringWithFormat:@"<%@: %p> type: %@, ID: %@, key: %@, delta: %@", self.class, self, typeName, self.ID, self.key, self.delta];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

@end
