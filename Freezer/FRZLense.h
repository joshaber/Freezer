//
//  FRZLense.h
//  Freezer
//
//  Created by Josh Abernathy on 4/13/14.
//  Copyright (c) 2014 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FRZLense : NSObject

@property (nonatomic, readonly, copy) id value;

- (id)add:(id<NSCopying>)value error:(NSError **)error;

- (id)remove:(NSError **)error;

@end
