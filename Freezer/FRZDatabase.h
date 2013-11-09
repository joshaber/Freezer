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
- (id)valueForKey:(NSString *)key;

// The same as -valueForKey:.
- (NSDictionary *)objectForKeyedSubscript:(NSString *)key;

// Get all the keys in the database.
- (NSSet *)allKeys;

// Find all the keys that have a given attribute.
//
// attribute - The attribute to find. Cannot be nil.
//
// Returns a set of NSString keys.
- (NSSet *)keysWithAttribute:(NSString *)attribute;

// Find the value for the given attribute of the given key.
//
// key       - The key whose attribute should be looked up. Cannot be nil.
// attribute - The attribute to look up. Cannot be nil.
//
// Returns the value.
- (id)valueForKey:(NSString *)key attribute:(NSString *)attribute;

@end
