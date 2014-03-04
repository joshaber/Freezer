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

static NSString * const testID = @"test";
static NSString * const testKey = @"key";
const id testValue = @42;

__block FRZStore *store;

beforeEach(^{
	store = [[FRZStore alloc] initInMemory:NULL];

	FRZTransactor *transactor = [store transactor];
	BOOL success = [transactor addValue:testValue forKey:testKey ID:testID error:NULL];
	expect(success).to.beTruthy();
});

describe(@"ID lookup", ^{
	it(@"should contain an ID after it's been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSDictionary *value = database[testID];
		expect(value).notTo.beNil();
		expect(value[testKey]).to.equal(testValue);
	});

	it(@"shouldn't contain any IDs after it's been removed", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor removeValueForKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSDictionary *value = database[testID];
		expect(value).to.beNil();
	});

	it(@"return nil for an ID that's never been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSDictionary *value = database[@"bullshit ID"];
		expect(value).to.beNil();
	});

	it(@"should return the latest value for an key added multiple times", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor addValue:@100 forKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSDictionary *value = database[testID];
		expect(value).notTo.beNil();
		expect(value[testKey]).to.equal(@100);
	});

	it(@"should continue to return the old value for old databases", ^{
		FRZDatabase *originalDatabase = [store currentDatabase];
		expect(originalDatabase).notTo.beNil();

		NSDictionary *originalValue = originalDatabase[testID];

		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor addValue:@100 forKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *updatedDatabase = [store currentDatabase];
		expect(updatedDatabase).notTo.beNil();

		NSDictionary *updatedValue = updatedDatabase[testID];
		expect(updatedValue).notTo.beNil();
		expect(updatedValue[testKey]).to.equal(@100);

		expect(originalDatabase[testID]).to.equal(originalValue);
	});
});

describe(@"-allIDs", ^{
	it(@"should contain an ID after it's been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();
		expect(database.allIDs).to.contain(testID);
	});

	it(@"shouldn't contain an ID after it's been removed", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor removeValueForKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();
		expect(database.allIDs).notTo.contain(testID);
	});
});

describe(@"-IDsWithKey:", ^{
	it(@"should contain an ID after it's been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSSet *IDs = [database IDsWithKey:testKey];
		expect(IDs).to.contain(testID);
	});

	it(@"shouldn't contain any IDs after it's been removed", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor removeValueForKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSSet *IDs = [database IDsWithKey:testKey];
		expect(IDs).notTo.contain(testID);
	});

	it(@"shouldn't contain any IDs for a key that's never been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		static NSString * const randomKey = @"some bullshit";
		NSSet *IDs = [database IDsWithKey:randomKey];
		expect(IDs.count).to.equal(0);
	});
});

describe(@"-valueForID:key:", ^{
	it(@"should find the value after it's been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		id value = [database valueForID:testID key:testKey];
		expect(value).to.equal(testValue);
	});

	it(@"shouldn't contain the value after it's been removed", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor removeValueForKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		id value = [database valueForID:testID key:testKey];
		expect(value).to.beNil();
	});

	it(@"shouldn't contain any value for a key that's never been added", ^{
		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		static NSString * const randomKey = @"some bullshit";
		id value = [database valueForID:testID key:randomKey];
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
		static NSString * const dateKey = @"date";

		NSDate *date = [NSDate date];
		BOOL success = [transactor addValue:date forKey:dateKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSDate *valueDate = [database valueForID:testID key:dateKey];
		expect([valueDate timeIntervalSinceDate:date]).to.beLessThan(0.001);
	});

	it(@"should support collections", ^{
		static NSString *collectionKey = @"lots";
		static NSString *collectionItemID = @"things";

		BOOL success = [transactor pushValue:@"first-key" forKey:collectionKey ID:collectionItemID error:NULL];
		expect(success).to.beTruthy();

		success = [transactor pushValue:@"second-key" forKey:collectionKey ID:collectionItemID error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSSet *value = [database valueForID:collectionItemID key:collectionKey];
		expect(value.count).to.equal(2);
		expect(value).to.contain(@"first-key");
		expect(value).to.contain(@"second-key");

		success = [transactor removeValue:@"first-key" forKey:collectionKey ID:collectionItemID error:NULL];
		expect(success).to.beTruthy();

		database = [store currentDatabase];
		expect(database).notTo.beNil();

		value = [database valueForID:collectionItemID key:collectionKey];
		expect(value.count).to.equal(1);
		expect(value).to.contain(@"second-key");
	});

	it(@"should keep collections separate based on parent key", ^{
		static NSString *collectionKey = @"lots";
		static NSString *collectionItemID = @"things";

		BOOL success = [transactor pushValue:@"first-key" forKey:collectionKey ID:collectionItemID error:NULL];
		expect(success).to.beTruthy();

		success = [transactor pushValue:@"second-key" forKey:collectionKey ID:collectionItemID error:NULL];
		expect(success).to.beTruthy();

		static NSString * const someOtherID = @"some-other-id";
		success = [transactor pushValue:@"third-key" forKey:collectionKey ID:someOtherID error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();

		NSSet *value = [database valueForID:collectionItemID key:collectionKey];
		expect(value.count).to.equal(2);
		expect(value).to.contain(@"first-key");
		expect(value).to.contain(@"second-key");
	});
});

SpecEnd
