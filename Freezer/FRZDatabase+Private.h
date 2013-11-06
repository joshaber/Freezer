 //
//  FRZDatabase+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZDatabase.h"

@class FRZStore;

@interface FRZDatabase ()

// Initializes the database with the given store and the transaction ID of the
// current head of the store.
//
// store  - The store to which the database belongs. Cannot be nil.
// headID - The ID of the current head of the store.
//
// Returns the initialized object.
- (id)initWithStore:(FRZStore *)store headID:(long long int)headID;

@end
