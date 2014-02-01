//
//  FRZSingleIDTransactor.h
//  Freezer
//
//  Created by Josh Abernathy on 11/8/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

// A transactor which will act on a single ID.
//
// Instances shouldn't be created directly. Instead, use
// -[FRZTransactor addValuesWithID:error:block:].
@interface FRZSingleIDTransactor : NSObject

// Add the given value for the given key.
//
// value - The value to add. Cannot be nil.
// key   - The key to which the value should be added. Cannot be nil.
// error - The error if one occurred.
//
// Returns whether the add was successful.
- (BOOL)addValue:(id<NSCoding>)value forKey:(NSString *)key error:(NSError **)error;

@end
