//
//  FRZStoreSpec.m
//  Freezer
//
//  Created by Josh Abernathy on 11/6/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZStore.h"

SpecBegin(FRZStore)

it(@"should be able to initialize in memory", ^{
	FRZStore *store = [[FRZStore alloc] initInMemory:NULL];
	expect(store).notTo.beNil();
});

SpecEnd
