//
//  FDAAppDelegate.m
//  FRZDemoApp
//
//  Created by Josh Abernathy on 11/8/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FDAAppDelegate.h"

@interface FDAAppDelegate ()

@property (nonatomic, readonly, strong) FRZStore *store;

@property (nonatomic, readonly, copy) NSString *path;

@end

@implementation FDAAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	_path = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
	_store = [[FRZStore alloc] initWithURL:[NSURL fileURLWithPath:self.path] error:NULL];

	[self testStuff];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	[NSFileManager.defaultManager removeItemAtPath:self.path error:NULL];
}

- (void)testStuff {
	static NSString * const firstNameKey = @"user/first-name";
	static NSString * const lastNameKey = @"user/last-name";
	static NSString * const hubbersKey = @"user/hubbers";

	FRZTransactor *transactor = [self.store transactor];
	NSString *hubbersID = [transactor generateNewID];
	[[[self.store.changes
		filter:^ BOOL (FRZChange *change) {
			return change.type == FRZChangeTypeAdd && [change.ID isEqual:hubbersID];
		}]
		map:^(FRZChange *change) {
			NSString *keyInserted = change.delta;
			return change.changedDatabase[keyInserted];
		}]
		subscribeNext:^(NSDictionary *x) {
			NSLog(@"%@ is a GitHubber!", x[firstNameKey]);
		}];

	[[[self.store
		valuesAndChangesForID:hubbersID]
		reduceEach:^(NSDictionary *value, id _) {
			return value[hubbersKey];
		}]
		subscribeNext:^(NSArray *hubbers) {
			NSLog(@" ");
			NSLog(@"Hubbers:");
			for (NSDictionary *hubber in hubbers) {
				NSLog(@"* %@ %@", hubber[firstNameKey], hubber[lastNameKey]);
			}

			NSLog(@" ");
		}];

	[transactor addKey:firstNameKey type:FRZTypeString collection:NO error:NULL];
	[transactor addKey:lastNameKey type:FRZTypeString collection:NO error:NULL];
	[transactor addKey:hubbersKey type:FRZTypeRef collection:YES error:NULL];

	NSString *joshID = [transactor generateNewID];
	[transactor addValuesWithID:joshID error:NULL block:^(FRZSingleIDTransactor *transactor, NSError **error) {
		[transactor addValue:@"Josh" forKey:firstNameKey error:error];
		[transactor addValue:@"Abernathy" forKey:lastNameKey error:error];
		return YES;
	}];

	[transactor addValue:joshID forKey:hubbersKey ID:hubbersID error:NULL];

	NSString *dannyID = [transactor generateNewID];
	[transactor addValuesWithID:dannyID error:NULL block:^(FRZSingleIDTransactor *transactor, NSError **error) {
		[transactor addValue:@"Danny" forKey:firstNameKey error:error];
		[transactor addValue:@"Greg" forKey:lastNameKey error:error];
		return YES;
	}];

	[transactor addValue:dannyID forKey:hubbersKey ID:hubbersID error:NULL];

	[transactor addValuesWithID:[transactor generateNewID] error:NULL block:^(FRZSingleIDTransactor *transactor, NSError **error) {
		[transactor addValue:@"John" forKey:firstNameKey error:error];
		[transactor addValue:@"Smith" forKey:lastNameKey error:error];
		return YES;
	}];

//	FRZDatabase *database = [self.store currentDatabase];
//	NSLog(@" ");
//	NSLog(@"Hubbers:");
//	NSSet *hubbers = [database valueForID:hubbersID key:hubbersKey];
//	for (NSDictionary *hubber in hubbers) {
//		NSLog(@"* %@ %@", hubber[firstNameKey], hubber[lastNameKey]);
//	}
//
//	NSLog(@" ");

	NSString *jssID = [transactor generateNewID];
	[transactor addValuesWithID:jssID error:NULL block:^(FRZSingleIDTransactor *transactor, NSError **error) {
		[transactor addValue:@"Justin" forKey:firstNameKey error:error];
		[transactor addValue:@"Spahr-Summers" forKey:lastNameKey error:error];
		return YES;
	}];

	[transactor addValue:jssID forKey:hubbersKey ID:hubbersID error:NULL];
}

- (void)testPerformance {
	static NSString * const testKey = @"testKey";
	FRZTransactor *transactor = [self.store transactor];
	[transactor addKey:testKey type:FRZTypeInteger collection:NO error:NULL];

	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
	__block NSUInteger writes = 0;
	[transactor performChangesWithError:NULL block:^(NSError **error) {
		while (YES) {
			if ([NSDate timeIntervalSinceReferenceDate] - start > 5) break;

			[transactor addValue:@42 forKey:testKey ID:[transactor generateNewID] error:NULL];

			writes++;
		}

		return YES;
	}];

	NSLog(@"Writes/sec: %lu", writes);

	FRZDatabase *database = [self.store currentDatabase];
	NSString *key = [self.store currentDatabase].allKeys.anyObject;
	start = [NSDate timeIntervalSinceReferenceDate];
	__block NSUInteger reads = 0;
	[transactor performChangesWithError:NULL block:^(NSError **error) {
		while (YES) {
			if ([NSDate timeIntervalSinceReferenceDate] - start > 5) break;

			id value __unused = database[key];

			reads++;
		}

		return YES;
	}];

	NSLog(@"Reads/sec: %lu", reads);
}

- (void)testQuery {
	FRZTransactor *transactor = [self.store transactor];

	static NSString * const testKey = @"test-key";
	[transactor addKey:testKey type:FRZTypeInteger collection:NO error:NULL];

	[transactor addValue:@42 forKey:testKey ID:@"test-id-1" error:NULL];
	[transactor addValue:@43 forKey:testKey ID:@"test-id-2" error:NULL];
	[transactor addValue:@42 forKey:testKey ID:@"test-id-3" error:NULL];

	FRZQuery *query = [[[self.store currentDatabase] query] filter:^(NSString *ID, NSString *key, id value) {
		return [value isEqual:@42];
	}];
	NSLog(@"%@", [query allIDs]);
}

@end
