//
//  FRZTransactor.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

// The transactor is responsible for effecting change to the store.
@interface FRZTransactor : NSObject

// Generate a new key to use for adding new values.
- (NSString *)generateNewKey;

// Apply changes to the store within the given block.
//
// error - The error if one occurs.
// block - The block in which adds or removes will be performed. Cannot be nil.
//
// Returns whether the changes were successful.
- (BOOL)applyChangesWithError:(NSError **)error block:(BOOL (^)(NSError **error))block;

// Adds a new value for the given attribute, associated with the given key.
//
// value     - The value to add. Cannot be nil.
// attribute - The attribute whose value will be added as `value`. Cannot be nil.
// key       - The key to associate with the attribute and value. Cannot be nil.
// error     - The error if one occurs.
//
// Returns whether the add was successful.
- (BOOL)addValue:(id<NSCoding>)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error;

// Removes the value for the given attribute and key.
//
// attribute - The attribute whose value should be removed. Cannot be nil.
// key       - The key whose associated attribute will be removed. Cannot be nil.
// error     - The error if one occurs.
//
// Returns whether the removal was successful.
- (BOOL)removeValueForAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error;

@end
