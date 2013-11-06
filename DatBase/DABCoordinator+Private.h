//
//  DABCoordinator+Private.h
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABCoordinator.h"

// The type of transaction to use.
//
//   DABCoordinatorTransactionTypeDeferred  - Defer lock acquisition until it is
//                                            needed.
//   DABCoordinatorTransactionTypeImmediate - Immediately acquire a write lock
//                                            on the database, but allow reads
//                                            to continue.
//   DABCoordinatorTransactionTypeExclusive - Immediately acquire an exclusive
//                                            lock on the database. No other
//                                            reads or writes will be allowed.
//
typedef enum : NSInteger {
	DABCoordinatorTransactionTypeDeferred,
	DABCoordinatorTransactionTypeImmediate,
	DABCoordinatorTransactionTypeExclusive,
} DABCoordinatorTransactionType;

@class FMDatabase;

@interface DABCoordinator ()

- (BOOL)performTransactionType:(DABCoordinatorTransactionType)transactionType error:(NSError **)error block:(BOOL (^)(FMDatabase *database, NSError **error))block;

- (long long int)headID:(NSError **)error;

@end
