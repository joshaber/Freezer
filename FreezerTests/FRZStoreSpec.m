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
	FRZDatabase *database = [store currentDatabase:NULL];
	expect(database).to.beNil();
});

it(@"should keep in-memory stores separate", ^{
	FRZStore *store1 = [[FRZStore alloc] initInMemory:NULL];
	FRZStore *store2 = [[FRZStore alloc] initInMemory:NULL];

	BOOL success = [[store1 transactor] addValue:@42 forAttribute:@"blah" key:@"test?" error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store2 currentDatabase:NULL];
	expect(database[@"test?"]).to.beNil();
});

it(@"should have a consistent database in different threads", ^{
	FRZStore *store = [[FRZStore alloc] initInMemory:NULL];

	static NSString * const testKey = @"test?";
	BOOL success = [[store transactor] addValue:@42 forAttribute:@"blah" key:testKey error:NULL];
	expect(success).to.beTruthy();

	FRZDatabase *database = [store currentDatabase:NULL];
	NSDictionary *value = database[testKey];
	expect(value).notTo.beNil();

	__block BOOL done = NO;
	__block NSDictionary *threadValue;
	dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		FRZDatabase *database = [store currentDatabase:NULL];
		threadValue = database[testKey];
		done = YES;
	});

	expect(done).will.beTruthy();
	expect(threadValue).to.equal(value);
});

SpecEnd
