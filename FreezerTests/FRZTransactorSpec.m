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

static NSString * const testKey = @"test-key";
static NSString * const testID = @"test-id";
const id testValue = @42;

__block FRZTransactor *transactor;
__block FRZStore *store;

beforeEach(^{
	store = [[FRZStore alloc] initInMemory:NULL];
	expect(store).notTo.beNil();

	transactor = [store transactor];
	expect(transactor).notTo.beNil();

	BOOL success = [transactor addKey:testKey type:FRZTypeInteger collection:NO error:NULL];
	expect(success).to.beTruthy();
});

it(@"should be able to generate a new ID", ^{
	NSString *ID = [transactor generateNewID];
	expect(ID).notTo.beNil();
});

it(@"", ^{
	BOOL success = [transactor addKey:testKey type:FRZTypeInteger collection:NO error:NULL];
	expect(success).to.beTruthy();

	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
	__block NSUInteger writes = 0;
	[transactor performChangesWithError:NULL block:^(NSError **error) {
		while (YES) {
			if ([NSDate timeIntervalSinceReferenceDate] - start > 1) break;

			[transactor addValue:@42 forKey:testKey ID:[transactor generateNewID] error:NULL];

			writes++;
		}

		return YES;
	}];

	[SPTReporter.sharedReporter printLine];
	[SPTReporter.sharedReporter printLineWithFormat:@"%lu writes", writes];
});

it(@"should be able to add new values", ^{
	BOOL success = [transactor addValue:testValue forKey:testKey ID:testID error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store currentDatabase];
	expect(database).notTo.beNil();
	expect([database valueForID:testID key:testKey]).to.equal(testValue);
});

it(@"should be able to remove values", ^{
	BOOL success = [transactor addValue:testValue forKey:testKey ID:testID error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store currentDatabase];
	expect(database).notTo.beNil();
	expect([database valueForID:testID key:testKey]).to.equal(testValue);

	[transactor removeValue:testValue forKey:testKey ID:testID error:NULL];
	database = [store currentDatabase];
	expect(database).notTo.beNil();
	expect([database valueForID:testID key:testKey]).to.beNil();
});

it(@"should only apply changes when the outermost transaction is completed", ^{
	const id testValue = @42;

	BOOL success = [transactor addKey:testKey type:FRZTypeInteger collection:NO error:NULL];
	expect(success).to.beTruthy();

	NSMutableArray *changes = [NSMutableArray array];
	[store.changes subscribeNext:^(id x) {
		[changes addObject:x];
	}];

	[transactor performChangesWithError:NULL block:^(NSError **error) {
		BOOL success = [transactor addValue:testValue forKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		expect(changes.count).to.equal(0);

		[transactor performChangesWithError:NULL block:^(NSError **error) {
			BOOL success = [transactor addValue:testValue forKey:testKey ID:testID error:NULL];
			expect(success).to.beTruthy();

			expect(changes.count).to.equal(0);

			return YES;
		}];

		expect(changes.count).to.equal(0);

		return YES;
	}];

	expect(changes.count).will.equal(2);
});

it(@"should support collections", ^{
	static NSString *collectionKey = @"lots";
	static NSString *collectionID = @"things";
	BOOL success = [transactor addKey:collectionKey type:FRZTypeString collection:YES error:NULL];
	expect(success).to.beTruthy();

	success = [transactor addValue:@"other-key" forKey:collectionKey ID:collectionID error:NULL];
	expect(success).to.beTruthy();

	success = [transactor removeValue:@"other-key" forKey:collectionKey ID:collectionID error:NULL];
	expect(success).to.beTruthy();

	NSDictionary *value = [store currentDatabase][collectionKey];
	expect([value[collectionID] count]).to.equal(0);
});

it(@"should trim", ^{
	BOOL success = [transactor addValue:testValue forKey:testKey ID:testID error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store currentDatabase];
	expect(database).notTo.beNil();
	expect([database valueForID:testID key:testKey]).to.equal(testValue);

	success = [transactor trim:NULL];
	expect(success).to.beTruthy();

	database = [store currentDatabase];
	expect(database).notTo.beNil();
	expect([database valueForID:testID key:testKey]).to.equal(testValue);
});

SpecEnd
