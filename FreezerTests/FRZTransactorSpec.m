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
#import "FRZSingleKeyTransactor.h"

SpecBegin(FRZTransactor)

static NSString * const testAttribute = @"testAttribute";
static NSString * const testKey = @"testKey";
const id testValue = @42;

__block FRZTransactor *transactor;
__block FRZStore *store;

beforeEach(^{
	store = [[FRZStore alloc] initInMemory:NULL];
	expect(store).notTo.beNil();

	transactor = [store transactor];
	expect(transactor).notTo.beNil();

	BOOL success = [transactor addAttribute:testAttribute type:FRZAttributeTypeInteger collection:NO error:NULL];
	expect(success).to.beTruthy();
});

it(@"should be able to generate a new key", ^{
	NSString *key = [transactor generateNewKey];
	expect(key).notTo.beNil();
});

it(@"", ^{
	BOOL success = [transactor addAttribute:testAttribute type:FRZAttributeTypeInteger collection:NO error:NULL];
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

it(@"should be able to add new values", ^{
	BOOL success = [transactor addValue:testValue forAttribute:testAttribute key:testKey error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store currentDatabase];
	expect(database).notTo.beNil();
	expect([database valueForKey:testKey attribute:testAttribute]).to.equal(testValue);
});

it(@"should be able to remove values", ^{
	BOOL success = [transactor addValue:testValue forAttribute:testAttribute key:testKey error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store currentDatabase];
	expect(database).notTo.beNil();
	expect([database valueForKey:testKey attribute:testAttribute]).to.equal(testValue);

	[transactor removeValue:testValue forAttribute:testAttribute key:testKey error:NULL];
	database = [store currentDatabase];
	expect(database).notTo.beNil();
	expect([database valueForKey:testKey attribute:testAttribute]).to.beNil();
});

it(@"should only apply changes when the outermost transaction is completed", ^{
	const id testValue = @42;

	BOOL success = [transactor addAttribute:testAttribute type:FRZAttributeTypeInteger collection:NO error:NULL];
	expect(success).to.beTruthy();

	NSMutableArray *changes = [NSMutableArray array];
	[store.changes subscribeNext:^(id x) {
		[changes addObject:x];
	}];

	[transactor performChangesWithError:NULL block:^(NSError **error) {
		BOOL success = [transactor addValue:testValue forAttribute:testAttribute key:testKey error:NULL];
		expect(success).to.beTruthy();

		expect(changes.count).to.equal(0);

		[transactor performChangesWithError:NULL block:^(NSError **error) {
			BOOL success = [transactor addValue:testValue forAttribute:testAttribute key:testKey error:NULL];
			expect(success).to.beTruthy();

			expect(changes.count).to.equal(0);

			return YES;
		}];

		expect(changes.count).to.equal(0);

		return YES;
	}];

	expect(changes.count).will.equal(2);
});

describe(@"-addValuesWithKey:error:block:", ^{
	it(@"should add the values to the key", ^{
		BOOL success = [transactor addValuesWithKey:testKey error:NULL block:^(FRZSingleKeyTransactor *transactor, NSError **error) {
			[transactor addValue:testValue forAttribute:testAttribute error:NULL];
			return YES;
		}];
		expect(success).to.beTruthy();

		FRZDatabase *database = [store currentDatabase];
		expect(database).notTo.beNil();
		expect([database valueForKey:testKey attribute:testAttribute]).to.equal(testValue);
	});

	it(@"should generate changes only after the block ends", ^{
		NSMutableArray *changes = [NSMutableArray array];
		[store.changes subscribeNext:^(id x) {
			[changes addObject:x];
		}];

		BOOL success = [transactor addValuesWithKey:testKey error:NULL block:^(FRZSingleKeyTransactor *transactor, NSError **error) {
			[transactor addValue:testValue forAttribute:testAttribute error:NULL];
			expect(changes.count).to.equal(0);

			[transactor addValue:@7 forAttribute:testAttribute error:NULL];
			expect(changes.count).to.equal(0);

			return YES;
		}];
		expect(success).to.beTruthy();

		expect(changes.count).will.equal(2);
	});
});

it(@"should support collections", ^{
	static NSString *collectionAttribute = @"lots";
	static NSString *collectionKey = @"things";
	BOOL success = [transactor addAttribute:collectionAttribute type:FRZAttributeTypeString collection:YES error:NULL];
	expect(success).to.beTruthy();

	success = [transactor addValue:@"other-key" forAttribute:collectionAttribute key:collectionKey error:NULL];
	expect(success).to.beTruthy();

	success = [transactor removeValue:@"other-key" forAttribute:collectionAttribute key:collectionKey error:NULL];
	expect(success).to.beTruthy();

	NSDictionary *value = [store currentDatabase][collectionKey];
	expect([value[collectionAttribute] count]).to.equal(0);
});

it(@"should trim", ^{
	BOOL success = [transactor addValue:testValue forAttribute:testAttribute key:testKey error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store currentDatabase];
	expect(database).notTo.beNil();
	expect([database valueForKey:testKey attribute:testAttribute]).to.equal(testValue);

	success = [transactor trim:NULL];
	expect(success).to.beTruthy();

	database = [store currentDatabase];
	expect(database).notTo.beNil();
	expect([database valueForKey:testKey attribute:testAttribute]).to.equal(testValue);
});

SpecEnd
