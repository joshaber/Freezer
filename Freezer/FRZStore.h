//
//  FRZStore.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FRZDatabase;
@class FRZTransactor;

// A Freezer store. This contains both the database, for reading values, and the
// transactor, for effecting change to the store.
@interface FRZStore : NSObject

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

// Gets the transactor for the store.
//
// Returns the transactor.
- (FRZTransactor *)transactor;

@end
