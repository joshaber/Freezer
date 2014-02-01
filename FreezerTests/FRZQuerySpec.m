//
//  FRZQuerySpec.m
//  Freezer
//
//  Created by Josh Abernathy on 12/29/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZQuery.h"
#import "FRZStore.h"
#import "FRZTransactor.h"
#import "FRZDatabase.h"

SpecBegin(FRZQuery)

static NSString * const testKey = @"test-key";

__block FRZTransactor *transactor;
__block FRZStore *store;
__block FRZQuery *query;

beforeEach(^{
	store = [[FRZStore alloc] initInMemory:NULL];
	expect(store).notTo.beNil();

	transactor = [store transactor];
	expect(transactor).notTo.beNil();

	BOOL success = [transactor addKey:testKey type:FRZTypeInteger collection:NO error:NULL];
	expect(success).to.beTruthy();

	for (int i = 0; i < 10; i++) {
		NSString *ID = [NSString stringWithFormat:@"%d", i];
		[transactor addValue:@(i) forKey:testKey ID:ID error:NULL];
	}

	query = [[store currentDatabase] query];
});

it(@"should give only as many results as take asks for", ^{
	FRZQuery *q = [query take:2];
	expect(q.allIDs.count).to.equal(2);
});

it(@"should filter using the filter block", ^{
	FRZQuery *q = [query filter:^ BOOL (NSString *ID, NSString *key, NSNumber *value) {
		if (![key isEqual:testKey]) return NO;

		return value.doubleValue < 3;
	}];

	NSSet *expected = [NSSet setWithObjects:@"0", @"1", @"2", nil];
	expect(q.allIDs).to.equal(expected);
});

SpecEnd
