//
//  FRZTransactorSpec.m
//  Freezer
//
//  Created by Josh Abernathy on 11/6/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZTransactor.h"
#import "FRZStore.h"
#import "FRZDatabase.h"
#import "SPTReporter.h"

SpecBegin(FRZTransactor)

static NSString * const testAttribute = @"testAttribute";
static NSString * const testKey = @"testKey";

__block FRZTransactor *transactor;
__block FRZStore *store;

beforeEach(^{
	store = [[FRZStore alloc] initInMemory:NULL];
	expect(store).notTo.beNil();

	transactor = [store transactor];
	expect(transactor).notTo.beNil();
});

it(@"should be able to generate a new key", ^{
	NSString *key = [transactor generateNewKey];
	expect(key).notTo.beNil();
});

it(@"", ^{
	BOOL success = [store addAttribute:testAttribute type:FRZAttributeTypeInteger error:NULL];
	expect(success).to.beTruthy();

	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
	__block NSUInteger writes = 0;
	[transactor performChangesWithError:NULL block:^(NSError **error) {
		while (YES) {
			if ([NSDate timeIntervalSinceReferenceDate] - start > 1) break;

			[transactor addValue:@42 forAttribute:testAttribute key:[transactor generateNewKey] error:NULL];

			writes++;
		}

		return YES;
	}];

	[SPTReporter.sharedReporter printLine];
	[SPTReporter.sharedReporter printLineWithFormat:@"%lu writes", writes];
});

describe(@"single values", ^{
	const id testValue = @42;

	beforeEach(^{
		BOOL success = [store addAttribute:testAttribute type:FRZAttributeTypeInteger error:NULL];
		expect(success).to.beTruthy();
	});

	it(@"should be able to add new values", ^{
		BOOL success = [transactor addValue:testValue forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();
		expect([database valueForKey:testKey attribute:testAttribute]).to.equal(testValue);
	});

	it(@"should be able to remove values", ^{
		BOOL success = [transactor addValue:testValue forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();
		expect([database valueForKey:testKey attribute:testAttribute]).to.equal(testValue);

		[transactor removeValue:testValue forAttribute:testAttribute key:testKey error:NULL];
		database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();
		expect([database valueForKey:testKey attribute:testAttribute]).to.beNil();
	});
});

describe(@"collections", ^{
	const id testValue = @[ @42, @43 ];

	beforeEach(^{
		BOOL success = [store addAttribute:testAttribute type:FRZAttributeTypeCollection error:NULL];
		expect(success).to.beTruthy();

		transactor = [store transactor];
		expect(transactor).notTo.beNil();
	});

	xit(@"should be able to add new values", ^{
		BOOL success = [transactor addValues:testValue forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();
		expect([database valueForKey:testKey attribute:testAttribute]).to.equal(testValue);
	});

	xit(@"should be able to remove values", ^{
		BOOL success = [transactor addValues:testValue forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();
		expect([database valueForKey:testKey attribute:testAttribute]).to.equal(testValue);

		[transactor removeValue:testValue forAttribute:testAttribute key:testKey error:NULL];
		database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();
		expect([database valueForKey:testKey attribute:testAttribute]).to.beNil();
	});
});

xit(@"should only apply changes when the outermost transaction is completed", ^{
	const id testValue = @42;

	BOOL success = [store addAttribute:testAttribute type:FRZAttributeTypeInteger error:NULL];
	expect(success).to.beTruthy();

	[transactor performChangesWithError:NULL block:^(NSError **error) {
		BOOL success = [transactor addValue:testValue forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();
		expect([database valueForKey:testKey attribute:testAttribute]).to.beNil();

		return YES;
	}];
});

SpecEnd
