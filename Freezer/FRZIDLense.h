//
//  FRZIDLense.h
//  Freezer
//
//  Created by Josh Abernathy on 4/3/14.
//  Copyright (c) 2014 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@class FRZKeyLense;

/// A lense focused on a single ID.
@interface FRZIDLense : NSObject <NSCopying>

/// The `FRZChange`s applied to the ID.
@property (nonatomic, readonly, strong) RACSignal *changes;

/// Create a new lense by focusing on a single key of the ID.
- (FRZKeyLense *)lenseWithKey:(NSString *)key;

@end
