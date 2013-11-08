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
	[transactor addAttribute:firstNameAttribute type:FRZAttributeTypeText error:NULL];
	[transactor addAttribute:lastNameAttribute type:FRZAttributeTypeText error:NULL];
	[transactor addAttribute:hubberAttribute type:FRZAttributeTypeInteger error:NULL];

	[transactor performChangesWithError:NULL block:^(NSError **error) {
		NSString *joshKey = [transactor generateNewKey];
		[transactor addValue:@"Josh" forAttribute:firstNameAttribute key:joshKey error:NULL];
		[transactor addValue:@"Abernathy" forAttribute:lastNameAttribute key:joshKey error:NULL];
		[transactor addValue:@1 forAttribute:hubberAttribute key:joshKey error:NULL];

		NSString *dannyKey = [transactor generateNewKey];
		[transactor addValue:@"Danny" forAttribute:firstNameAttribute key:dannyKey error:NULL];
		[transactor addValue:@"Greg" forAttribute:lastNameAttribute key:dannyKey error:NULL];
		[transactor addValue:@1 forAttribute:hubberAttribute key:dannyKey error:NULL];

		NSString *johnKey = [transactor generateNewKey];
		[transactor addValue:@"John" forAttribute:firstNameAttribute key:johnKey error:NULL];
		[transactor addValue:@"Smith" forAttribute:lastNameAttribute key:johnKey error:NULL];

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
}

@end
