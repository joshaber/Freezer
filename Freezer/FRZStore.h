//
//  FRZStore.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

// The domain for all general errors coming out of Freezer.
extern NSString * const FRZErrorDomain;

@class FRZDatabase;
@class FRZTransactor;

// A Freezer store. This contains both the database, for reading values, and the
// transactor, for effecting change to the store.
@interface FRZStore : NSObject

// A signal of NSArrays of FRZChange items, one for each change done by a
// transactor. These will be sent on a private scheduler after a transaction has
// been committed.
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
// Returns the database.
- (FRZDatabase *)currentDatabase;

// Gets the transactor for the store.
//
// Returns the transactor.
- (FRZTransactor *)transactor;

// Starts by sending an array of a tuple of the current value for the ID and
// nil, and then sends a new array of value-change tuples each time a change is
// done to the ID.
- (RACSignal *)valuesAndChangesForID:(NSString *)ID;

@end
