//
//  FRZQuery.h
//  Freezer
//
//  Created by Josh Abernathy on 12/27/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FRZQuery : NSObject

// The block used to filter the results.
@property (nonatomic, copy) BOOL (^filter)(NSString *key, NSString *attribute, id value);

// The number of results to take.
@property (nonatomic, assign) NSUInteger take;

// Get all the keys which pass `filter` and are limited by `take`.
- (NSArray *)allKeys;

@end
