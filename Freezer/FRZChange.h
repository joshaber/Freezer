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

// The delta of the change. This is context-dependent. For adds, this is the new
// value. For removes, this is nil.
@property (nonatomic, readonly, strong) id delta;

// The database before the change was applied.
@property (nonatomic, readonly, copy) FRZDatabase *previousDatabase;

// The database after the change was applied.
@property (nonatomic, readonly, copy) FRZDatabase *changedDatabase;

@end
