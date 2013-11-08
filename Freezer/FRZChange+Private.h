//
//  FRZChange+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 11/6/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZChange.h"

@interface FRZChange ()

@property (nonatomic, readwrite, copy) FRZDatabase *previousDatabase;

@property (nonatomic, readwrite, copy) FRZDatabase *changedDatabase;

// Initializes the receiver with the given values.
//
// type             - The type of change.
// key              - The key whose value of attribute was changed. Cannot be
//                    nil.
// attribute        - The attribute whose value was changed. Cannot be nil.
// delta            - The delta for the change. May be nil.
//
// Returns the initialized object.
- (id)initWithType:(FRZChangeType)type key:(NSString *)key attribute:(NSString *)attribute delta:(id)delta;

@end
