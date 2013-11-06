//
//  FRZChange.h
//  Freezer
//
//  Created by Josh Abernathy on 11/6/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

@class FRZDatabase;

// The type of change made.
//   FRZChangeTypeAdd        - A new value was added.
//   FRZChangeTypeAddMany    - Values were added to a collection.
//   FRZChangeTypeRemove     - An existing value was removed.
//   FRZChangeTypeRemoveMany - Values were removed from a collection.
typedef enum : NSInteger {
	FRZChangeTypeAdd,
	FRZChangeTypeAddMany,
	FRZChangeTypeRemove,
	FRZChangeTypeRemoveMany,
} FRZChangeType;

// A change that was applied to a store.
@interface FRZChange : NSObject <NSCopying>

// The type of the change.
@property (nonatomic, readonly, assign) FRZChangeType type;

// The key which was changed.
@property (nonatomic, readonly, copy) NSString *key;

// The attribute which was changed.
@property (nonatomic, readonly, copy) NSString *attribute;

// The delta of the change. This is change type-dependent.
//   FRZChangeTypeAdd        - The value added.
//   FRZChangeTypeAddMany    - The NSArray added.
//   FRZChangeTypeRemove     - nil.
//   FRZChangeTypeRemoveMany - The NSArray removed.
@property (nonatomic, readonly, strong) id delta;

// The database before the change was applied.
@property (nonatomic, readonly, copy) FRZDatabase *previousDatabase;

// The database after the change was applied.
@property (nonatomic, readonly, copy) FRZDatabase *changedDatabase;

@end
