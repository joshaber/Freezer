//
//  FRZQuery_Private.h
//  Freezer
//
//  Created by Josh Abernathy on 12/27/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZQuery.h"

@class FRZDatabase;

@interface FRZQuery ()

// Initializes the query with the given database.
//
// database - The database which the query will query. Cannot be nil.
//
// Returns the initialized object.
- (id)initWithDatabase:(FRZDatabase *)database;

@end
