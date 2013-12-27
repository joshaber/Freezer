//
//  FRZTransactor+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZTransactor.h"

@class FRZStore;

@interface FRZTransactor ()

// Initializes the transactor with the given store.
//
// store - The store which the transactor will modify. Cannot be nil.
//
// Returns the initialized object.
- (id)initWithStore:(FRZStore *)store;

// Insert a new transaction into the database.
//
// database - The database into which the transaction will be inserted. Cannot
//            be nil.
// error    - The error if one occurred.
//
// Returns the inserted transaction's ID, or -1 if an error occurred.
- (long long int)insertNewTransactionIntoDatabase:(FMDatabase *)database error:(NSError **)error;

// Update the database's head transaction ID to `ID`.
//
// database - The database whose head transaction is being updated. Cannot be
//            nil.
// ID       - The ID of the new head transaction.
// error    - The error if one occurred.
//
// Returns whether the update was successful.
- (BOOL)updateHeadInDatabase:(FMDatabase *)database toID:(long long int)ID error:(NSError **)error;

@end
