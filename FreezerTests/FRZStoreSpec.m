//
//  FRZStoreSpec.m
//  Freezer
//
//  Created by Josh Abernathy on 11/6/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZStore.h"
#import "FRZTransactor.h"
#import "FRZDatabase.h"
#import "FRZChange.h"

SpecBegin(FRZStore)

it(@"should be able to initialize in memory", ^{
	FRZStore *store = [[FRZStore alloc] initInMemory:NULL];
	expect(store).notTo.beNil();
});

it(@"should be able to initialize with a URL", ^{
	NSString *UUID = [[NSUUID UUID] UUIDString];
	NSURL *URL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:UUID]];
	FRZStore *store = [[FRZStore alloc] initWithURL:URL error:NULL];
	expect(store).notTo.beNil();
});

it(@"should return a non-nil transactor", ^{
	FRZStore *store = [[FRZStore alloc] initInMemory:NULL];
	expect([store transactor]).notTo.beNil();
});

it(@"should have a nil database before anything's been added", ^{
	FRZStore *store = [[FRZStore alloc] initInMemory:NULL];
	FRZDatabase *database = [store currentDatabase];
	expect(database).to.beNil();
});

it(@"should keep in-memory stores separate", ^{
	FRZStore *store1 = [[FRZStore alloc] initInMemory:NULL];
	static NSString *testAttribute = @"blah";
	BOOL success = [[store1 transactor] addAttribute:testAttribute type:FRZAttributeTypeInteger collection:NO error:NULL];
	expect(success).to.beTruthy();

	FRZStore *store2 = [[FRZStore alloc] initInMemory:NULL];

	success = [[store1 transactor] addValue:@42 forAttribute:testAttribute key:@"test?" error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store2 currentDatabase];
	expect(database[@"test?"]).to.beNil();
});

it(@"should have a consistent database in different threads", ^{
	static NSString * const testAttribute = @"blah";
	static NSString * const testKey = @"test?";
	FRZStore *store = [[FRZStore alloc] initInMemory:NULL];
	BOOL success = [[store transactor] addAttribute:testAttribute type:FRZAttributeTypeInteger collection:NO error:NULL];
	expect(success).to.beTruthy();

	success = [[store transactor] addValue:@42 forAttribute:testAttribute key:testKey error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store currentDatabase];
	NSDictionary *value = database[testKey];
	expect(value).notTo.beNil();

	__block BOOL done = NO;
	__block NSDictionary *threadValue;
	dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		FRZDatabase *database = [store currentDatabase];
		threadValue = database[testKey];
		done = YES;
	});

	expect(done).will.beTruthy();
	expect(threadValue).to.equal(value);
});

describe(@"changes", ^{
	static NSString * const testAttribute = @"test-attr";

	__block FRZStore *store;
	__block FRZTransactor *transactor;

	beforeEach(^{
		store = [[FRZStore alloc] initInMemory:NULL];
		expect(store).notTo.beNil();

		transactor = [store transactor];
		expect(transactor).notTo.beNil();

		BOOL success = [transactor addAttribute:testAttribute type:FRZAttributeTypeInteger collection:NO error:NULL];
		expect(success).to.beTruthy();
	});

	it(@"should send adds as they occur", ^{
		NSMutableArray *changes = [NSMutableArray array];
		[store.changes subscribeNext:^(FRZChange *change) {
			[changes addObject:change];
		}];

		const id value = @42;
		static NSString * const testKey = @"test-key";
		[transactor addValue:@41 forAttribute:testAttribute key:testKey error:NULL];
		[transactor addValue:value forAttribute:testAttribute key:testKey error:NULL];
		expect(changes.count).will.equal(2);

		FRZChange *change = changes.lastObject;
		expect(change.type).to.equal(FRZChangeTypeAdd);
		expect(change.delta).to.equal(value);
		expect(change.attribute).to.equal(testAttribute);
		expect(change.key).to.equal(testKey);
		expect(change.previousDatabase[testKey][testAttribute]).notTo.equal(value);
		expect(change.changedDatabase[testKey][testAttribute]).to.equal(value);
	});

	it(@"should send removes as they occur", ^{
		NSMutableArray *changes = [NSMutableArray array];
		[store.changes subscribeNext:^(FRZChange *change) {
			[changes addObject:change];
		}];

		const id value = @42;
		static NSString * const testKey = @"test-key";
		[transactor addValue:value forAttribute:testAttribute key:testKey error:NULL];
		[transactor removeValue:value forAttribute:testAttribute key:testKey error:NULL];
		expect(changes.count).will.equal(2);

		FRZChange *change = changes.lastObject;
		expect(change.type).to.equal(FRZChangeTypeRemove);
		expect(change.delta).to.equal(value);
		expect(change.attribute).to.equal(testAttribute);
		expect(change.key).to.equal(testKey);
		expect(change.previousDatabase[testKey][testAttribute]).to.equal(value);
		expect(change.changedDatabase[testKey][testAttribute]).to.beNil();
	});

	it(@"should send the database after the transaction's completed", ^{
		static NSString * const testKey = @"some-key";
		static NSString * const testAttribute1 = @"attr1";
		static NSString * const testAttribute2 = @"attr2";

		BOOL success = [transactor addAttribute:testAttribute1 type:FRZAttributeTypeInteger collection:NO error:NULL];
		expect(success).to.beTruthy();

		success = [transactor addAttribute:testAttribute2 type:FRZAttributeTypeInteger collection:NO error:NULL];
		expect(success).to.beTruthy();

		__block FRZDatabase *database;
		[store.changes subscribeNext:^(FRZChange *change) {
			database = change.changedDatabase;
		}];

		[transactor performChangesWithError:NULL block:^(NSError **error) {
			BOOL success = [transactor addValue:@42 forAttribute:testAttribute1 key:testKey error:NULL];
			expect(success).to.beTruthy();

			success = [transactor addValue:@7 forAttribute:testAttribute2 key:testKey error:NULL];
			expect(success).to.beTruthy();

			return YES;
		}];

		NSDictionary *expected = @{
			testAttribute1: @42,
			testAttribute2: @7,
		};
		expect(database[testKey]).to.equal(expected);
	});
});

SpecEnd
