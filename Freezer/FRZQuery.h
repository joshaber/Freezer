//
//  FRZQuery.h
//  Freezer
//
//  Created by Josh Abernathy on 12/27/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FRZQuery : NSObject

// Creates a new query based on the receiver which filters using the given
// block.
//
// Note that this will replace the receiver's `filter` block, if it has one.
//
// filter - The block used to filter results. Cannot be nil.
//
// Returns the new query.
- (instancetype)filter:(BOOL (^)(NSString *ID, NSString *key, id value))filter;

// Creates a new query based on the receiver which will take only `take` number
// of results.
//
// Note that this will replace the receiver's `take`, if one has been set.
//
// take - The number of results to take before stopping. 0 means take all
//        results.
//
// Returns the new query.
- (instancetype)take:(NSUInteger)take;

// Get all the IDs which pass `filter` and are limited by `take`.
- (NSSet *)allIDs;

@end
