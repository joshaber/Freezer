//
//  FRZDatabaseSpec.m
//  Freezer
//
//  Created by Josh Abernathy on 11/6/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZDatabase.h"
#import "FRZStore.h"
#import "FRZTransactor.h"

SpecBegin(FRZDatabase)

static NSString * const testKey = @"test";
static NSString * const testAttribute = @"attr";
const id testValue = @42;

__block FRZStore *store;

beforeEach(^{
	store = [[FRZStore alloc] initInMemory:NULL];

	FRZTransactor *transactor = [store transactor];
	BOOL success = [transactor addAttribute:testAttribute type:FRZAttributeTypeInteger collection:NO error:NULL];
	expect(success).to.beTruthy();

	success = [transactor addValue:testValue forAttribute:testAttribute key:testKey error:NULL];
	expect(success).to.beTruthy();
});

describe(@"key lookup", ^{
	it(@"should contain a key after it's been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSDictionary *value = database[testKey];
		expect(value).notTo.beNil();
		expect(value[testAttribute]).to.equal(testValue);
	});

	it(@"shouldn't contain any keys after it's been removed", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor removeValue:testValue forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSDictionary *value = database[testKey];
		expect(value).to.beNil();
	});

	it(@"return nil for a key that's never been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSDictionary *value = database[@"bullshit key"];
		expect(value).to.beNil();
	});

	it(@"should return the latest value for an attribute added multiple times", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor addValue:@100 forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSDictionary *value = database[testKey];
		expect(value).notTo.beNil();
		expect(value[testAttribute]).to.equal(@100);
	});

	it(@"should continue to return the old value for old databases", ^{
		FRZDatabase *originalDatabase = [store currentDatabase];
		expect(originalDatabase).notTo.beNil();

		NSDictionary *originalValue = originalDatabase[testKey];

		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor addValue:@100 forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *updatedDatabase = [store currentDatabase];
		expect(updatedDatabase).notTo.beNil();

		NSDictionary *updatedValue = updatedDatabase[testKey];
		expect(updatedValue).notTo.beNil();
		expect(updatedValue[testAttribute]).to.equal(@100);

		expect(originalDatabase[testKey]).to.equal(originalValue);
	});
});

describe(@"-allKeys", ^{
	it(@"should contain a key after it's been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();
		expect(database.allKeys).to.contain(testKey);
	});

	it(@"shouldn't contain a key after it's been removed", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor removeValue:testValue forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();
		expect(database.allKeys).notTo.contain(testKey);
	});
});

describe(@"-keysWithAttribute:", ^{
	it(@"should contain a key after it's been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSSet *keys = [database keysWithAttribute:testAttribute];
		expect(keys).to.contain(testKey);
	});

	it(@"shouldn't contain any keys after it's been removed", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor removeValue:testValue forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSSet *keys = [database keysWithAttribute:testAttribute];
		expect(keys).notTo.contain(testKey);
	});

	it(@"shouldn't contain any keys for an attribute that's never been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		static NSString * const randomAttribute = @"some bullshit";
		BOOL success = [[store transactor] addAttribute:randomAttribute type:FRZAttributeTypeInteger collection:NO error:NULL];
		expect(success).to.beTruthy();

		NSSet *keys = [database keysWithAttribute:randomAttribute];
		expect(keys.count).to.equal(0);
	});
});

describe(@"-valueForKey:attribute:", ^{
	it(@"should find the value after it's been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		id value = [database valueForKey:testKey attribute:testAttribute];
		expect(value).to.equal(testValue);
	});

	it(@"shouldn't contain the value after it's been removed", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor removeValue:testValue forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		id value = [database valueForKey:testKey attribute:testAttribute];
		expect(value).to.beNil();
	});

	it(@"shouldn't contain any value for an attribute that's never been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		static NSString * const randomAttribute = @"some bullshit";
		BOOL success = [[store transactor] addAttribute:randomAttribute type:FRZAttributeTypeInteger collection:NO error:NULL];
		expect(success).to.beTruthy();

		id value = [database valueForKey:testKey attribute:randomAttribute];
		expect(value).to.beNil();
	});
});

describe(@"special types", ^{
	__block FRZTransactor *transactor;

	beforeEach(^{
		transactor = [store transactor];
		expect(transactor).notTo.beNil();
	});

	it(@"should be able to add and get dates", ^{
		static NSString * const dateAttribute = @"date";
		BOOL success = [transactor addAttribute:dateAttribute type:FRZAttributeTypeDate collection:NO error:NULL];
		expect(success).to.beTruthy();

		NSDate *date = [NSDate date];
		success = [transactor addValue:date forAttribute:dateAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSDate *valueDate = [database valueForKey:testKey attribute:dateAttribute];
		expect([valueDate timeIntervalSinceDate:date]).to.beLessThan(0.001);
	});

	it(@"should be able to add and get refs", ^{
		static NSString * const refAttribute = @"ref";
		BOOL success = [transactor addAttribute:refAttribute type:FRZAttributeTypeRef collection:NO error:NULL];
		expect(success).to.beTruthy();

		success = [transactor addValue:testValue forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		NSString *key = [transactor generateNewKey];
		success = [transactor addValue:testKey forAttribute:refAttribute key:key error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSDictionary *expected = @{ testAttribute: testValue };
		id value = [database valueForKey:key attribute:refAttribute];
		expect(value).to.equal(expected);
	});

	it(@"should support collections", ^{
		static NSString *collectionAttribute = @"lots";
		static NSString *collectionItemKey = @"things";
		BOOL success = [transactor addAttribute:collectionAttribute type:FRZAttributeTypeString collection:YES error:NULL];
		expect(success).to.beTruthy();

		success = [transactor addValue:@"first-key" forAttribute:collectionAttribute key:collectionItemKey error:NULL];
		expect(success).to.beTruthy();

		success = [transactor addValue:@"second-key" forAttribute:collectionAttribute key:collectionItemKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSSet *value = [database valueForKey:collectionItemKey attribute:collectionAttribute];
		expect(value.count).to.equal(2);
		expect(value).to.contain(@"first-key");
		expect(value).to.contain(@"second-key");

		success = [transactor removeValue:@"first-key" forAttribute:collectionAttribute key:collectionItemKey error:NULL];
		expect(success).to.beTruthy();

		database = [store currentDatabase];
		expect(database).notTo.beNil();

		value = [database valueForKey:collectionItemKey attribute:collectionAttribute];
		expect(value.count).to.equal(1);
		expect(value).to.contain(@"second-key");
	});

	it(@"should keep collections separate based on parent key", ^{
		static NSString *collection = @"lots";
		static NSString *collectionItemKey = @"things";
		BOOL success = [transactor addAttribute:collection type:FRZAttributeTypeString collection:YES error:NULL];
		expect(success).to.beTruthy();

		success = [transactor addValue:@"first-key" forAttribute:collection key:collectionItemKey error:NULL];
		expect(success).to.beTruthy();

		success = [transactor addValue:@"second-key" forAttribute:collection key:collectionItemKey error:NULL];
		expect(success).to.beTruthy();

		static NSString * const someOtherKey = @"some-other-key";
		success = [transactor addValue:@"third-key" forAttribute:collection key:someOtherKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSSet *value = [database valueForKey:collectionItemKey attribute:collection];
		expect(value.count).to.equal(2);
		expect(value).to.contain(@"first-key");
		expect(value).to.contain(@"second-key");
	});
});

SpecEnd
