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
	NSURL *URL = [NSURL fileURLWithPath:@"/Users/joshaber/Desktop/DatBase/test.sqlite"];
	[NSFileManager.defaultManager removeItemAtURL:URL error:NULL];

	DABCoordinator *coordinator = [[DABCoordinator alloc] initWithDatabaseAtURL:URL error:&error];
	NSAssert(coordinator != nil, @"Coordinator was nil: %@", error);

	DABTransactor *transactor = [coordinator transactor];

	NSString *UUID = [[NSUUID UUID] UUIDString];
	[transactor addValue:@42 forAttribute:@"answer" key:UUID error:NULL];
	[transactor addValue:@26 forAttribute:@"age" key:UUID error:NULL];
	[transactor addValue:@27 forAttribute:@"age" key:UUID error:NULL];
	[transactor addValue:@43 forAttribute:@"answer" key:UUID error:NULL];

	DABDatabase *database1 = [coordinator currentDatabase:NULL];
	NSDictionary *result = database1[UUID];
	NSLog(@"%@", result);

	[transactor addValue:@42 forAttribute:@"answer" key:UUID error:NULL];
	DABDatabase *database2 = [coordinator currentDatabase:NULL];
	result = database2[UUID];
	NSLog(@"%@", result);

	result = database1[UUID];
	NSLog(@"%@", result);

	NSLog(@"%@", database1.allKeys);

	NSString *jssKey = [transactor generateNewKey];
	[transactor addValue:@"Justin" forAttribute:@"first-name" key:jssKey error:NULL];
	[transactor addValue:@"Spahr-Summers" forAttribute:@"last-name" key:jssKey error:NULL];

	NSString *dannyKey = [transactor generateNewKey];
	[transactor addValue:@"Danny" forAttribute:@"first-name" key:dannyKey error:NULL];
	[transactor addValue:@"Greg" forAttribute:@"last-name" key:dannyKey error:NULL];

	NSString *joshKey = [transactor generateNewKey];
	[transactor addValue:@"Josh" forAttribute:@"first-name" key:joshKey error:NULL];
	[transactor addValue:@"Abernathy" forAttribute:@"last-name" key:joshKey error:NULL];
	[transactor addValue:@[ jssKey ] forAttribute:@"homies" key:joshKey error:NULL];

	DABDatabase *database3 = [coordinator currentDatabase:NULL];
	NSLog(@"%@", database3[joshKey]);
	NSLog(@"%@", database3[database3[joshKey][@"homies"][0]]);

	[transactor addValue:@[ jssKey, dannyKey ] forAttribute:@"homies" key:joshKey error:NULL];

	DABDatabase *database4 = [coordinator currentDatabase:NULL];
	NSLog(@"%@", database4[joshKey]);
	NSLog(@"%@", database4[database4[joshKey][@"homies"][1]]);

	[transactor removeValueForAttribute:@"homies" key:joshKey error:NULL];
	DABDatabase *database5 = [coordinator currentDatabase:NULL];
	NSLog(@"%@", database5[joshKey]);

	NSArray *keys = [database5 keysWithAttribute:@"first-name" error:NULL];
	NSLog(@"%@", keys);

//	[self doABunchOfWrites:transactor coordinator:coordinator];

//	DABDatabase *originalDatabase = [coordinator currentDatabase:&error];
//	NSAssert(originalDatabase != nil, @"Original database was nil: %@", error);
//
//	static NSString * const attribute = @"answer";
//	NSNumber *answer = @42;
//	DABTransactor *transactor = [coordinator transactor];
//	NSString *newKey = [transactor generateNewKey];
//	[transactor runTransaction:^{
//		NSError *error;
//		NSString *key = [transactor addValue:@43 forAttribute:attribute key:newKey error:&error];
//		NSAssert(key != nil, @"Key was nil: %@", error);
//
//		key = [transactor addValue:answer forAttribute:attribute key:newKey error:&error];
//		NSAssert(key != nil, @"Key was nil: %@", error);
//
//	}];
//
//	DABDatabase *database = [coordinator currentDatabase:&error];
//	NSAssert(database != nil, @"Database was nil: %@", error);
//
//	NSDictionary *values = database[newKey];
//	NSString *value = values[attribute];
//	NSAssert([value isEqual:answer], @"Value was not \"%@\": %@", answer, value);
//
//	values = originalDatabase[newKey];
//	value = values[attribute];
//	NSAssert(![value isEqual:answer], @"Found the updated value even though we shouldn't see it :(");
//
//	NSLog(@"%@", database.allKeys);
}

//- (void)doABunchOfWrites:(DABTransactor *)transactor coordinator:(DABCoordinator *)coordinator {
//	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
//
//	static const NSUInteger count = 1000;
//	static NSString * const attribute = @"attribute";
//	NSString *newKey = [transactor generateNewKey];
//	for (NSUInteger i = 0; i < count; i++) {
//		NSError *error;
//		id valueToInsert = @(i);
//		BOOL success = [transactor addValue:valueToInsert forAttribute:attribute key:newKey error:&error];
//		if (!success) {
//			NSLog(@"Error: %@", error);
//			return;
//		}
//
////		DABDatabase *database = [coordinator currentDatabase:NULL];
////		NSDictionary *x = database[newKey];
////		NSAssert(x != nil, nil);
////		NSAssert([x[@"key"] isEqual:newKey], nil);
////		id value = [NSKeyedUnarchiver unarchiveObjectWithData:x[@"value"]];
////		NSAssert([value isEqual:valueToInsert], nil);
//	}
//
//	NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];
//	NSTimeInterval totalTime = end - start;
//	NSLog(@"%f adds/sec", count / totalTime);
//}

@end
