//
//  FRZSingleKeyTransactor.h
//  Freezer
//
//  Created by Josh Abernathy on 11/8/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

// A transactor which will act on a single key.
//
// Instances shouldn't be created directly. Instead, use
// -[FRZTransactor addValuesWithKey:error:block:].
@interface FRZSingleKeyTransactor : NSObject

// Add the given value for the given attribute.
//
// value     - The value to add. Cannot be nil.
// attribute - The attribute to which the value should be added. Cannot be nil.
// error     - The error if one occurred.
//
// Returns whether the add was successful.
- (BOOL)addValue:(id)value forAttribute:(NSString *)attribute error:(NSError **)error;

@end
