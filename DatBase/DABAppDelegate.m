//
//  DABAppDelegate.m
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABAppDelegate.h"
#import "DABCoordinator.h"
#import "DABDatabase.h"
#import "DABTransactor.h"

@implementation DABAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	NSError *error;
	DABCoordinator *coordinator = [DABCoordinator createDatabaseAtURL:[NSURL fileURLWithPath:@"/Users/joshaber/Desktop/DatBase/test.git"] error:&error];
	NSAssert(coordinator != nil, @"Coordinator was nil: %@", error);

	DABDatabase *originalDatabase = [coordinator currentDatabase:&error];
	NSAssert(originalDatabase != nil, @"Original database was nil: %@", error);

	static NSString * const attribute = @"answer";
	NSNumber *answer = @42;
	DABTransactor *transactor = [coordinator transactor];
	NSString *newKey = [transactor generateNewKey];
	[transactor runTransaction:^{
		NSError *error;
		NSString *key = [transactor addValue:@43 forAttribute:attribute key:newKey error:&error];
		NSAssert(key != nil, @"Key was nil: %@", error);

		key = [transactor addValue:answer forAttribute:attribute key:newKey error:&error];
		NSAssert(key != nil, @"Key was nil: %@", error);

	}];

	DABDatabase *database = [coordinator currentDatabase:&error];
	NSAssert(database != nil, @"Database was nil: %@", error);

	NSDictionary *values = database[newKey];
	NSString *value = values[attribute];
	NSAssert([value isEqual:answer], @"Value was not \"%@\": %@", answer, value);

	values = originalDatabase[newKey];
	value = values[attribute];
	NSAssert(![value isEqual:answer], @"Found the updated value even though we shouldn't see it :(");

	NSLog(@"%@", database.allKeys);
}

@end
