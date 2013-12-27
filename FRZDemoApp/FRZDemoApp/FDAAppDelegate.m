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

@end

@implementation FDAAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
	_store = [[FRZStore alloc] initWithURL:[NSURL fileURLWithPath:path] error:NULL];

	[self testPerformance];
}

- (void)testStuff {
	static NSString * const firstNameAttribute = @"user/first-name";
	static NSString * const lastNameAttribute = @"user/last-name";
	static NSString * const hubbersAttribute = @"user/hubbers";

	FRZTransactor *transactor = [self.store transactor];
	NSString *hubbersKey = [transactor generateNewKey];
	[[[self.store.changes
	   filter:^ BOOL (FRZChange *change) {
		   return change.type == FRZChangeTypeAdd && [change.key isEqual:hubbersKey];
	   }]
	  map:^(FRZChange *change) {
		  NSString *keyInserted = change.delta;
		  return change.changedDatabase[keyInserted];
	  }]
	 subscribeNext:^(NSDictionary *x) {
		 NSLog(@"%@ is a GitHubber!", x[firstNameAttribute]);
	 }];

	[transactor addAttribute:firstNameAttribute type:FRZAttributeTypeString collection:NO error:NULL];
	[transactor addAttribute:lastNameAttribute type:FRZAttributeTypeString collection:NO error:NULL];
	[transactor addAttribute:hubbersAttribute type:FRZAttributeTypeRef collection:YES error:NULL];

	NSString *joshKey = [transactor generateNewKey];
	[transactor addValuesWithKey:joshKey error:NULL block:^(FRZSingleKeyTransactor *transactor, NSError **error) {
		[transactor addValue:@"Josh" forAttribute:firstNameAttribute error:error];
		[transactor addValue:@"Abernathy" forAttribute:lastNameAttribute error:error];
		return YES;
	}];

	[transactor addValue:joshKey forAttribute:hubbersAttribute key:hubbersKey error:NULL];

	NSString *dannyKey = [transactor generateNewKey];
	[transactor addValuesWithKey:dannyKey error:NULL block:^(FRZSingleKeyTransactor *transactor, NSError **error) {
		[transactor addValue:@"Danny" forAttribute:firstNameAttribute error:error];
		[transactor addValue:@"Greg" forAttribute:lastNameAttribute error:error];
		return YES;
	}];

	[transactor addValue:dannyKey forAttribute:hubbersAttribute key:hubbersKey error:NULL];

	[transactor addValuesWithKey:[transactor generateNewKey] error:NULL block:^(FRZSingleKeyTransactor *transactor, NSError **error) {
		[transactor addValue:@"John" forAttribute:firstNameAttribute error:error];
		[transactor addValue:@"Smith" forAttribute:lastNameAttribute error:error];
		return YES;
	}];

	FRZDatabase *database = [self.store currentDatabase];
	NSLog(@" ");
	NSLog(@"Hubbers:");
	NSSet *hubbers = [database valueForKey:hubbersKey attribute:hubbersAttribute];
	for (NSDictionary *hubber in hubbers) {
		NSLog(@"* %@ %@", hubber[firstNameAttribute], hubber[lastNameAttribute]);
	}

	NSString *jssKey = [transactor generateNewKey];
	[transactor addValuesWithKey:jssKey error:NULL block:^(FRZSingleKeyTransactor *transactor, NSError **error) {
		[transactor addValue:@"Justin" forAttribute:firstNameAttribute error:error];
		[transactor addValue:@"Spahr-Summers" forAttribute:lastNameAttribute error:error];
		return YES;
	}];

	[transactor addValue:jssKey forAttribute:hubbersAttribute key:hubbersKey error:NULL];
}

- (void)testPerformance {
	static NSString * const testAttribute = @"testAttribute";
	FRZTransactor *transactor = [self.store transactor];
	[transactor addAttribute:testAttribute type:FRZAttributeTypeInteger collection:NO error:NULL];

	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
	__block NSUInteger writes = 0;
	[transactor performChangesWithError:NULL block:^(NSError **error) {
		while (YES) {
			if ([NSDate timeIntervalSinceReferenceDate] - start > 5) break;

			[transactor addValue:@42 forAttribute:testAttribute key:[transactor generateNewKey] error:NULL];

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

@end
