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

// Generate a new ID to use for adding new values.
- (NSString *)generateNewID;

// Adds a new value for the given key, associated with the given ID.
//
// value - The value to add. Cannot be nil.
// key   - The key whose value will be added as `value`. Cannot be nil.
// ID    - The ID to associate with the key and value. Cannot be nil.
// error - The error if one occurs.
//
// Returns whether the add was successful.
- (BOOL)addValue:(id<NSCoding>)value forKey:(NSString *)key ID:(NSString *)ID error:(NSError **)error;

// Add all the key-value pairs in `keyedValues` to `ID`.
//
// keyedValues - The key-value pairs to add. Cannot be nil.
// ID          - The ID for the key-value pairs. Cannot be nil.
// error       - The error if one occurred.
//
// Returns whether the add was successful.
- (BOOL)addValues:(NSDictionary *)keyedValues forID:(NSString *)ID error:(NSError **)error;

// Removes the value for the given key and ID, but only if the given value
// matches the current value. If the current value does not match the given
// value, then the method returns NO and the error code will be
// FRZErrorInvalidValue.
//
// value - The value which should be removed. Cannot be nil.
// key   - The key whose value should be removed. Cannot be nil.
// ID    - The ID whose associated key will be removed. Cannot be nil.
// error - The error if one occurs.
//
// Returns whether the removal was successful.
- (BOOL)removeValue:(id)value forKey:(NSString *)key ID:(NSString *)ID error:(NSError **)error;

// Perform changes to the store within the given block.
//
// error - The error if one occurs.
// block - The block in which adds or removes will be performed. Cannot be nil.
//
// Returns whether the changes were successful.
- (BOOL)performChangesWithError:(NSError **)error block:(BOOL (^)(NSError **error))block;

// Trim old IDs and values from the store.
//
// Note that this *does* effectively change existing databases in place. This
// makes it a dangerous operation that should only be done when you can
// guarantee that there are no FRZDatabase instances alive. Meaning it's
// probably best to do this at the app launch or quit.
//
// error - The error if one occurred.
//
// Returns whether the trim was successful.
- (BOOL)trim:(NSError **)error;

@end
