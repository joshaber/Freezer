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
// database - The database to query. Cannot be nil.
//
// Returns the initialized object.
- (id)initWithDatabase:(FRZDatabase *)database;

// Initializes the query with the given database, filter, and take limit.
//
// database - The database to query. Cannot be nil.
// filter   - The filter block. May be nil.
// take     - The take limit. 0 means unlimited.
//
// Returns the initialized object.
- (id)initWithDatabase:(FRZDatabase *)database filter:(BOOL (^)(NSString *ID, NSString *key, id value))filter take:(NSUInteger)take;

@end
