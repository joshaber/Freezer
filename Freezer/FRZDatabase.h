//
//  FRZDatabase.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FRZQuery;
@class FRZLense;
@class FRZTransactor;

// A database as retrieved from a store.
@interface FRZDatabase : NSObject <NSCopying>

// Look up all the keys and values for the given ID.
//
// ID - The ID to look up. Cannot be nil.
//
// Returns of the keys and values for that ID.
- (id)valueForID:(NSString *)ID;

// The same as -valueForID:.
- (NSDictionary *)objectForKeyedSubscript:(NSString *)ID;

// Get all the IDs in the database.
- (NSSet *)allIDs;

// Find all the IDs that have a given key.
//
// key - The key to find. Cannot be nil.
//
// Returns a set of NSString IDs.
- (NSSet *)IDsWithKey:(NSString *)key;

// Find the value for the given key of the given ID. If the key is of the type
// FRZTypeRef, then the reference is resolved.
//
// ID  - The ID whose key should be looked up. Cannot be nil.
// key - The key to look up. Cannot be nil.
//
// Returns the value.
- (id)valueForID:(NSString *)ID key:(NSString *)key;

// Find the values for the given keys of the given ID.
//
// ID   - The ID whose key should be looked up. Cannot be nil.
// keys - The keys to look up. Cannot be nil.
//
// Returns the dictionary of values.
- (NSDictionary *)valuesForID:(NSString *)key keys:(NSArray *)keys;

// Get all the keys in the database.
- (NSSet *)allKeys;

// Create and return a new query to search the database.
- (FRZQuery *)query;

- (FRZLense *)lenseWithRead:(id (^)(FRZDatabase *database, NSError **error))read add:(id (^)(id value, FRZTransactor *transactor, NSError **error))add remove:(id (^)(id value, FRZTransactor *transactor, NSError **error))remove;

@end
