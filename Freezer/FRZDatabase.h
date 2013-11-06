//
//  FRZDatabase.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

// A database as retrieved from a store.
@interface FRZDatabase : NSObject <NSCopying>

// Look up all the attributes and values for the given key.
//
// key - The key to look up. Cannot be nil.
//
// Returns of the attributes and values for that key.
- (NSDictionary *)objectForKeyedSubscript:(NSString *)key;

// Get all the keys in the database.
- (NSArray *)allKeys;

// Find all the keys that have a given attribute.
//
// attribute - The attribute to find. Cannot be nil.
// error     - The error if one occurred.
//
// Returns an array of NSString keys.
- (NSArray *)keysWithAttribute:(NSString *)attribute error:(NSError **)error;

@end
