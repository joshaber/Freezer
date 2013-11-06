//
//  FRZCoordinator+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZCoordinator.h"

// The type of transaction to use.
//
//   FRZCoordinatorTransactionTypeDeferred  - Defer lock acquisition until it is
//                                            needed.
//   FRZCoordinatorTransactionTypeImmediate - Immediately acquire a write lock
//                                            on the database, but allow reads
//                                            to continue.
//   FRZCoordinatorTransactionTypeExclusive - Immediately acquire an exclusive
//                                            lock on the database. No other
//                                            reads or writes will be allowed.
//
typedef enum : NSInteger {
	FRZCoordinatorTransactionTypeDeferred,
	FRZCoordinatorTransactionTypeImmediate,
	FRZCoordinatorTransactionTypeExclusive,
} FRZCoordinatorTransactionType;

@class FMDatabase;

@interface FRZCoordinator ()

- (BOOL)performTransactionType:(FRZCoordinatorTransactionType)transactionType error:(NSError **)error block:(BOOL (^)(FMDatabase *database, NSError **error))block;

- (long long int)headID:(NSError **)error;

@end
