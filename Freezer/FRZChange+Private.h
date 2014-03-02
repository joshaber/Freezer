//
//  FRZChange+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 11/6/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZChange.h"

@interface FRZChange ()

@property (atomic, readwrite, copy) FRZDatabase *previousDatabase;

@property (atomic, readwrite, copy) FRZDatabase *changedDatabase;

// Initializes the receiver with the given values.
//
// type  - The type of change.
// ID    - The ID whose value of key was changed. Cannot be nil.
// key   - The key whose value was changed. Cannot be nil.
// delta - The delta for the change. Cannot be nil.
//
// Returns the initialized object.
- (id)initWithType:(FRZChangeType)type ID:(NSString *)ID key:(NSString *)key delta:(id)delta;

@end
