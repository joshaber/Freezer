//
//  FRZStoreSpec.m
//  Freezer
//
//  Created by Josh Abernathy on 11/6/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZStore.h"
#import "FRZStore+Private.h"
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
	static NSString *testKey = @"blah";

	FRZStore *store2 = [[FRZStore alloc] initInMemory:NULL];

	BOOL success = [[store1 transactor] addValue:@42 forKey:testKey ID:@"test?" error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store2 currentDatabase];
	expect(database[@"test?"]).to.beNil();
});

it(@"should have a consistent database in different threads", ^{
	static NSString * const testKey = @"blah";
	static NSString * const testID = @"test?";
	FRZStore *store = [[FRZStore alloc] initInMemory:NULL];

	BOOL success = [[store transactor] addValue:@42 forKey:testKey ID:testID error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store currentDatabase];
	NSDictionary *value = database[testID];
	expect(value).notTo.beNil();

	__block BOOL done = NO;
	__block NSDictionary *threadValue;
	dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		FRZDatabase *database = [store currentDatabase];
		threadValue = database[testID];
		done = YES;
	});

	expect(done).will.beTruthy();
	expect(threadValue).to.equal(value);
});

describe(@"changes", ^{
	static NSString * const testKey = @"test-key";

	__block FRZStore *store;
	__block FRZTransactor *transactor;

	beforeEach(^{
		store = [[FRZStore alloc] initInMemory:NULL];
		expect(store).notTo.beNil();

		transactor = [store transactor];
		expect(transactor).notTo.beNil();
	});

	it(@"should send adds as they occur", ^{
		NSMutableArray *changes = [NSMutableArray array];
		[store.changes subscribeNext:^(FRZChange *change) {
			[changes addObject:change];
		}];

		const id value = @42;
		static NSString * const testID = @"test-id";
		[transactor addValue:@41 forKey:testKey ID:testID error:NULL];
		[transactor addValue:value forKey:testKey ID:testID error:NULL];
		expect(changes.count).will.equal(2);

		FRZChange *change = changes.lastObject;
		expect(change.type).to.equal(FRZChangeTypeAdd);
		expect(change.delta).to.equal(value);
		expect(change.ID).to.equal(testID);
		expect(change.key).to.equal(testKey);
		expect(change.previousDatabase[testID][testKey]).notTo.equal(value);
		expect(change.changedDatabase[testID][testKey]).to.equal(value);
	});

	it(@"should send removes as they occur", ^{
		NSMutableArray *changes = [NSMutableArray array];
		[store.changes subscribeNext:^(FRZChange *change) {
			[changes addObject:change];
		}];

		const id value = @42;
		static NSString * const testID = @"test-id";
		[transactor addValue:value forKey:testKey ID:testID error:NULL];
		[transactor removeValue:value forKey:testKey ID:testID error:NULL];
		expect(changes.count).will.equal(2);

		FRZChange *change = changes.lastObject;
		expect(change.type).to.equal(FRZChangeTypeRemove);
		expect(change.delta).to.equal(value);
		expect(change.ID).to.equal(testID);
		expect(change.key).to.equal(testKey);
		expect(change.previousDatabase[testID][testKey]).to.equal(value);
		expect(change.changedDatabase[testID][testKey]).to.beNil();
	});

	it(@"should send the database after the transaction's completed", ^{
		static NSString * const testID = @"some-id";
		static NSString * const testKey1 = @"key1";
		static NSString * const testKey2 = @"key2";

		__block FRZDatabase *database;
		[store.changes subscribeNext:^(FRZChange *change) {
			database = change.changedDatabase;
		}];

		[transactor performChangesWithError:NULL block:^(NSError **error) {
			BOOL success = [transactor addValue:@42 forKey:testKey1 ID:testID error:NULL];
			expect(success).to.beTruthy();

			success = [transactor addValue:@7 forKey:testKey2 ID:testID error:NULL];
			expect(success).to.beTruthy();

			return YES;
		}];

		NSDictionary *expected = @{
			testKey1: @42,
			testKey2: @7,
		};
		expect(database[testID]).will.equal(expected);
	});
});

describe(@"trimming", ^{
	static NSString * const testKey = @"test-key";
	static NSString * const testID = @"test-id";
	const id testValue = @42;

	__block FRZStore *store;
	__block FRZTransactor *transactor;

	beforeEach(^{
		store = [[FRZStore alloc] initInMemory:NULL];
		transactor = [store transactor];
	});

	it(@"should remove deleted entries", ^{
		long long int startingEntryCount = [store entryCount];

		BOOL success = [transactor addValue:testValue forKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();
		expect([store entryCount]).to.beGreaterThan(startingEntryCount);

		success = [transactor removeValue:testValue forKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		success = [transactor trim:NULL];
		expect(success).to.beTruthy();

		expect([store entryCount]).to.equal(startingEntryCount);
	});

	it(@"should remove old entries", ^{
		BOOL success = [transactor addValue:testValue forKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		success = [transactor trim:NULL];
		expect(success).to.beTruthy();

		long long int startingEntryCount = [store entryCount];

		success = [transactor addValue:@43 forKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();
		expect([store entryCount]).to.beGreaterThan(startingEntryCount);

		success = [transactor trim:NULL];
		expect(success).to.beTruthy();

		expect([store entryCount]).to.equal(startingEntryCount);
	});

	it(@"shouldn't trim the latest values", ^{
		BOOL success = [transactor addValue:testValue forKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		const id latest = @43;
		success = [transactor addValue:latest forKey:testKey ID:testID error:NULL];
		expect(success).to.beTruthy();

		success = [transactor trim:NULL];
		expect(success).to.beTruthy();

		expect([store currentDatabase][testID][testKey]).to.equal(latest);
	});
});

SpecEnd
