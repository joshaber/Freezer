//
//  FRZSingleIDTransactor+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 11/8/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZSingleIDTransactor.h"

@class FRZTransactor;

@interface FRZSingleIDTransactor ()

// Initialize the receiver with the given transactor and key.
//
// transactor - The parent transactor to which the receiver belongs. Cannot be
//              nil.
// ID         - The ID on which the receiver will be acting. Cannot be nil.
//
// Returns the initialized object.
- (id)initWithTransactor:(FRZTransactor *)transactor ID:(NSString *)ID;

@end
