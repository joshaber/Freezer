//
//  FRZQuery.h
//  Freezer
//
//  Created by Josh Abernathy on 12/27/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FRZQuery : NSObject

- (FRZQuery *)filter:(BOOL (^)(NSString *key, NSString *attribute, id value))block;

- (NSArray *)allKeys;

@end
