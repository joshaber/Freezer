//
//  FRZChange.h
//  Freezer
//
//  Created by Josh Abernathy on 11/6/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

@class FRZDatabase;

// The type of change made.
//   FRZChangeTypeAdd    - A new value was added.
//   FRZChangeTypeRemove - An existing value was removed.
typedef enum : NSInteger {
	FRZChangeTypeAdd,
	FRZChangeTypeRemove,
} FRZChangeType;

// A change that was applied to a store.
@interface FRZChange : NSObject <NSCopying>

// The type of the change.
@property (nonatomic, readonly, assign) FRZChangeType type;

// The key which was changed.
@property (nonatomic, readonly, copy) NSString *key;

// The attribute which was changed.
@property (nonatomic, readonly, copy) NSString *attribute;

// The value which was added or removed.
@property (nonatomic, readonly, strong) id delta;

// The database before the change was applied. This may be nil if the addition
// was the first value added to the store.
@property (nonatomic, readonly, copy) FRZDatabase *previousDatabase;

// The database after the change was applied.
@property (nonatomic, readonly, copy) FRZDatabase *changedDatabase;

// Initializes the receiver with the given properties.
//
// type             - The type of change.
// key              - The key whose value of attribute was changed. Cannot be
//                    nil.
// attribute        - The attribute whose value was changed. Cannot be nil.
// delta            - The delta for the change. Cannot be nil.
// previousDatabase - The database before the change. May be nil.
// changedDatabase  - The database after the change. Cannot be nil.
//
// Returns the initialized object.
- (id)initWithType:(FRZChangeType)type key:(NSString *)key attribute:(NSString *)attribute delta:(id)delta previousDatabase:(FRZDatabase *)previousDatabase changedDatabase:(FRZDatabase *)changedDatabase;

@end
