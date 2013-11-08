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

	static NSString * const nameAttribute = @"user/names";
	static NSString * const hireDateAttribute = @"user/hire-date";

	[[[self.store.changes
		filter:^ BOOL (FRZChange *change) {
			return change.type == FRZChangeTypeAdd && [change.attribute isEqual:nameAttribute];
		}]
		map:^(FRZChange *change) {
			return change.changedDatabase[change.key];
		}]
		subscribeNext:^(NSDictionary *x) {
			NSLog(@"Added %@", x);
		}];

	FRZTransactor *transactor = [self.store transactor];
	[transactor addAttribute:nameAttribute type:FRZAttributeTypeText error:NULL];
	[transactor addAttribute:hireDateAttribute type:FRZAttributeTypeDate error:NULL];

	[transactor performChangesWithError:NULL block:^BOOL(NSError *__autoreleasing *error) {
		[transactor addValue:@"Josh" forAttribute:nameAttribute key:[transactor generateNewKey] error:NULL];
		[transactor addValue:@"Danny" forAttribute:nameAttribute key:[transactor generateNewKey] error:NULL];
		[transactor addValue:@"Justin" forAttribute:nameAttribute key:[transactor generateNewKey] error:NULL];
		[transactor addValue:@"Alan" forAttribute:nameAttribute key:[transactor generateNewKey] error:NULL];

		NSString *robKey = [transactor generateNewKey];
		[transactor addValue:@"Rob" forAttribute:nameAttribute key:robKey error:NULL];
		[transactor addValue:[NSDate date] forAttribute:hireDateAttribute key:robKey error:NULL];

		return YES;
	}];
}

@end
