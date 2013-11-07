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
	BOOL success = [transactor addValue:testValue forAttribute:testAttribute key:testKey error:NULL];
	expect(success).to.beTruthy();
});

describe(@"key lookup", ^{
	it(@"should contain a key after it's been added", ^{
		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();

		NSDictionary *value = database[testKey];
		expect(value).notTo.beNil();
		expect(value[testAttribute]).to.equal(testValue);
	});

	it(@"shouldn't contain any keys after it's been removed", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor removeValueForAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();

		NSDictionary *value = database[testKey];
		expect(value).to.beNil();
	});

	it(@"return nil for a key that's never been added", ^{
		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();

		NSDictionary *value = database[@"bullshit key"];
		expect(value).to.beNil();
	});

	it(@"should return the latest value for an attribute added multiple times", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor addValue:@100 forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();

		NSDictionary *value = database[testKey];
		expect(value).notTo.beNil();
		expect(value[testAttribute]).to.equal(@100);
	});

	it(@"should continue to return the old value for old databases", ^{
		FRZDatabase *originalDatabase = [store currentDatabase:NULL];
		expect(originalDatabase).notTo.beNil();

		NSDictionary *originalValue = originalDatabase[testKey];

		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor addValue:@100 forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *updatedDatabase = [store currentDatabase:NULL];
		expect(updatedDatabase).notTo.beNil();

		NSDictionary *updatedValue = updatedDatabase[testKey];
		expect(updatedValue).notTo.beNil();
		expect(updatedValue[testAttribute]).to.equal(@100);

		expect(originalDatabase[testKey]).to.equal(originalValue);
	});
});

describe(@"-allKeys", ^{
	it(@"should contain a key after it's been added", ^{
		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();
		expect(database.allKeys).to.contain(testKey);
	});

	it(@"shouldn't contain a key after it's been removed", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor removeValueForAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();
		expect(database.allKeys).notTo.contain(testKey);
	});
});

describe(@"-keysWithAttribute:error:", ^{
	it(@"should contain a key after it's been added", ^{
		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();

		NSArray *keys = [database keysWithAttribute:testAttribute error:NULL];
		expect(keys).to.contain(testKey);
	});

	it(@"shouldn't contain any keys after it's been removed", ^{
		FRZTransactor *transactor = [store transactor];
		BOOL success = [transactor removeValueForAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();

		NSArray *keys = [database keysWithAttribute:testAttribute error:NULL];
		expect(keys).to.contain(testKey);
	});

	it(@"shouldn't contain any keys for an attribute that's never been added", ^{
		FRZDatabase *database = [store currentDatabase:NULL];
		expect(database).notTo.beNil();

		NSArray *keys = [database keysWithAttribute:@"some bullshit" error:NULL];
		expect(keys.count).to.equal(0);
	});
});

SpecEnd