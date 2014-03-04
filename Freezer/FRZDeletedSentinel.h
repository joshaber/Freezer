//
//  FRZDeletedSentinel.h
//  Freezer
//
//  Created by Josh Abernathy on 3/3/14.
//  Copyright (c) 2014 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

/// The sentinel value that marks a key-value as having been deleted.
@interface FRZDeletedSentinel : NSObject <NSCoding>

/// The singleton instance of the sentinel.
+ (instancetype)deletedSentinel;

@end
