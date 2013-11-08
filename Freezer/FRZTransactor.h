//
//  FRZTransactor.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

// The valid attribute types.
//   FRZAttributeTypeInteger    - Integer type.
//   FRZAttributeTypeReal       - Real numbers type.
//   FRZAttributeTypeString     - String type.
//   FRZAttributeTypeBlob       - Data blob type.
//   FRZAttributeTypeDate       - Date type.
//   FRZAttributeTypeRef        - Reference to another key.
typedef enum : NSInteger {
	FRZAttributeTypeInteger = 1,
	FRZAttributeTypeReal,
	FRZAttributeTypeString,
	FRZAttributeTypeBlob,
	FRZAttributeTypeDate,
	FRZAttributeTypeRef,
} FRZAttributeType;

// The transactor is responsible for effecting change to the store.
@interface FRZTransactor : NSObject

// Generate a new key to use for adding new values.
- (NSString *)generateNewKey;

// Add an attribute of the given type to the store.
//
// attribute - The name of the attribute to add. Cannot be nil.
// type      - The type of the attribute.
// error     - The error if one occurred.
//
// Returns whether the attribute addition was successful.
- (BOOL)addAttribute:(NSString *)attribute type:(FRZAttributeType)type error:(NSError **)error;

// Perform changes to the store within the given block.
//
// error - The error if one occurs.
// block - The block in which adds or removes will be performed. Cannot be nil.
//
// Returns whether the changes were successful.
- (BOOL)performChangesWithError:(NSError **)error block:(BOOL (^)(NSError **error))block;

// Adds a new value for the given attribute, associated with the given key.
//
// value     - The value to add. Cannot be nil.
// attribute - The attribute whose value will be added as `value`. Cannot be nil.
// key       - The key to associate with the attribute and value. Cannot be nil.
// error     - The error if one occurs.
//
// Returns whether the add was successful.
- (BOOL)addValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error;

// Removes the value for the given attribute and key, but only if the given
// value matches the current value. If the current value does not match the
// given value, then the method returns NO and the error code will be
// FRZErrorInvalidValue.
//
// value     - The value which should be removed. Cannot be nil.
// attribute - The attribute whose value should be removed. Cannot be nil.
// key       - The key whose associated attribute will be removed. Cannot be nil.
// error     - The error if one occurs.
//
// Returns whether the removal was successful.
- (BOOL)removeValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error;

@end
