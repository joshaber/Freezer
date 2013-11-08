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
	_store = [[FRZStore alloc] initInMemory:NULL];

	static NSString * const firstNameAttribute = @"user/first-name";
	static NSString * const lastNameAttribute = @"user/last-name";
	static NSString * const hubberAttribute = @"user/hubber";

	[[[self.store.changes
		filter:^ BOOL (FRZChange *change) {
			return change.type == FRZChangeTypeAdd && [change.attribute isEqual:hubberAttribute];
		}]
		map:^(FRZChange *change) {
			return change.changedDatabase[change.key];
		}]
		subscribeNext:^(NSDictionary *x) {
			NSLog(@"%@ is a GitHubber!", x[firstNameAttribute]);
		}];

	FRZTransactor *transactor = [self.store transactor];
	[transactor addAttribute:firstNameAttribute type:FRZAttributeTypeString error:NULL];
	[transactor addAttribute:lastNameAttribute type:FRZAttributeTypeString error:NULL];
	[transactor addAttribute:hubberAttribute type:FRZAttributeTypeInteger error:NULL];

	[transactor addValuesWithKey:[transactor generateNewKey] error:NULL block:^(FRZSingleKeyTransactor *transactor, NSError **error) {
		[transactor addValue:@"Josh" forAttribute:firstNameAttribute error:error];
		[transactor addValue:@"Abernathy" forAttribute:lastNameAttribute error:error];
		[transactor addValue:@1 forAttribute:hubberAttribute error:error];
		return YES;
	}];

	[transactor addValuesWithKey:[transactor generateNewKey] error:NULL block:^(FRZSingleKeyTransactor *transactor, NSError **error) {
		[transactor addValue:@"Danny" forAttribute:firstNameAttribute error:error];
		[transactor addValue:@"Greg" forAttribute:lastNameAttribute error:error];
		[transactor addValue:@1 forAttribute:hubberAttribute error:error];
		return YES;
	}];

	[transactor addValuesWithKey:[transactor generateNewKey] error:NULL block:^(FRZSingleKeyTransactor *transactor, NSError **error) {
		[transactor addValue:@"John" forAttribute:firstNameAttribute error:error];
		[transactor addValue:@"Smith" forAttribute:lastNameAttribute error:error];
		return YES;
	}];

	FRZDatabase *database = [self.store currentDatabase:NULL];
	NSLog(@" ");
	NSLog(@"Hubbers:");
	NSSet *hubberKeys = [database keysWithAttribute:hubberAttribute];
	for (NSString *key in hubberKeys) {
		NSLog(@"* %@ %@", [database valueForKey:key attribute:firstNameAttribute], [database valueForKey:key attribute:lastNameAttribute]);
	}

	NSLog(@" ");
	NSLog(@"Not Hubbers:");
	NSSet *namedKeys = [database keysWithAttribute:firstNameAttribute];
	NSMutableSet *nonHubberKeys = [namedKeys mutableCopy];
	[nonHubberKeys minusSet:hubberKeys];
	for (NSString *key in nonHubberKeys) {
		NSLog(@"* %@ %@", [database valueForKey:key attribute:firstNameAttribute], [database valueForKey:key attribute:lastNameAttribute]);
	}

	[transactor addValuesWithKey:[transactor generateNewKey] error:NULL block:^(FRZSingleKeyTransactor *transactor, NSError **error) {
		[transactor addValue:@"Justin" forAttribute:firstNameAttribute error:error];
		[transactor addValue:@"Spahr-Summers" forAttribute:lastNameAttribute error:error];
		[transactor addValue:@1 forAttribute:hubberAttribute error:error];
		return YES;
	}];
}

@end
