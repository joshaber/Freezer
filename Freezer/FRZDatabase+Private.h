 //
//  FRZDatabase+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZDatabase.h"

@class FRZStore;
@class FMDatabase;

@interface FRZDatabase ()

// The store to which the database belongs.
@property (nonatomic, readonly, strong) FRZStore *store;

// The head ID to which the database points.
@property (nonatomic, readonly, assign) long long int headID;

// Initializes the database with the given store and the transaction ID of the
// current head of the store.
//
// store  - The store to which the database belongs. Cannot be nil.
// headID - The ID of the current head of the store.
//
// Returns the initialized object.
- (id)initWithStore:(FRZStore *)store headID:(long long int)headID;

// Get the single value for the given key and ID in the database.
//
// ID         - The ID whose value should be retrieved. Cannot be nil.
// key        - The key whose value should be retrieved. Cannot be nil.
// database   - The database to use for the lookup.
// success    - Was the lookup successful?
// error      - The error if one occurred.
//
// Returns the value.
- (id)singleValueForKey:(NSString *)key ID:(NSString *)ID inDatabase:(FMDatabase *)database success:(BOOL *)success error:(NSError **)error;

@end
