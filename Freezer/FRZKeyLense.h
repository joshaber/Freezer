//
//  FRZKeyLense.h
//  Freezer
//
//  Created by Josh Abernathy on 4/3/14.
//  Copyright (c) 2014 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@class FRZIDLense;

/// A lense focused on a single key of a single ID.
@interface FRZKeyLense : NSObject <NSCopying>

/// A signal of all the FRZChanges applied to the value of the key.
@property (nonatomic, readonly, strong) RACSignal *changes;

/// The value of the key at the time the lense was created.
@property (nonatomic, readonly, copy) id value;

/// Add the given value for the key.
- (FRZKeyLense *)addValue:(id<NSCopying>)value error:(NSError **)error;

/// Push the value to the set.
- (FRZKeyLense *)pushValue:(id<NSCopying>)value error:(NSError **)error;

/// Remove the value.
- (FRZKeyLense *)remove:(NSError **)error;

/// Remove the given value from the set.
- (FRZKeyLense *)removeValue:(id)value error:(NSError **)error;

/// Create a new lense for the ID `value`.
- (FRZIDLense *)lenseWithID;

/// Create a set of `FRZIDLense`s for each ID in `value`.
- (NSSet *)lensesWithIDs;

@end
