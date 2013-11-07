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

@end
