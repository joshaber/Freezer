//
//  FRZStore.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

// The valid attribute types.
//   FRZAttributeTypeInteger    - Integer type.
//   FRZAttributeTypeReal       - Real numbers type.
//   FRZAttributeTypeText       - Arbitrary text type.
//   FRZAttributeTypeBlob       - Data blob type.
//   FRZAttributeTypeDate       - Date type.
//   FRZAttributeTypeRef        - Reference to another key.
//   FRZAttributeTypeCollection - A collection of values.
typedef enum : NSInteger {
	FRZAttributeTypeInteger,
	FRZAttributeTypeReal,
	FRZAttributeTypeText,
	FRZAttributeTypeBlob,
	FRZAttributeTypeDate,
	FRZAttributeTypeRef,
	FRZAttributeTypeCollection,
} FRZAttributeType;

@class FRZDatabase;
@class FRZTransactor;

// A Freezer store. This contains both the database, for reading values, and the
// transactor, for effecting change to the store.
@interface FRZStore : NSObject

// A signal of FRZChange items, one for each change done by a transactor. These
// will be sent on a private scheduler.
@property (nonatomic, readonly, strong) RACSignal *changes;

// Initializes the store to exist in memory only.
//
// error - The error if one occurs.
//
// Returns the initialized object, or nil if an error occurs.
- (id)initInMemory:(NSError **)error;

// Initializes the store with the given URL for the store's database.
//
// URL   - The URL for the store's database. Cannot be nil.
// error - The error if one occurred.
//
// Returns the initialized object, or nil if an error occurred.
- (id)initWithURL:(NSURL *)URL error:(NSError **)error;

// Gets the current database. The returned database is immutable.
//
// error - The error if one occurred.
//
// Returns the database, or nil if an error occurred.
- (FRZDatabase *)currentDatabase:(NSError **)error;

// Add an attribute of the given type to the store.
//
// attribute - The name of the attribute to add. Cannot be nil.
// type      - The type of the attribute.
// error     - The error if one occurred.
//
// Returns whether the attribute addition was successful.
- (BOOL)addAttribute:(NSString *)attribute type:(FRZAttributeType)type error:(NSError **)error;

// Gets the transactor for the store.
//
// Returns the transactor.
- (FRZTransactor *)transactor;

@end
