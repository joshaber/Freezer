//
//  FRZStore+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZStore.h"
#import <sqlite3.h>

// The type of transaction to use.
//
//   FRZStoreTransactionTypeDeferred  - Defer lock acquisition until it is
//                                      needed.
//   FRZStoreTransactionTypeImmediate - Immediately acquire a write lock on the
//                                      database, but allow reads to continue.
//   FRZStoreTransactionTypeExclusive - Immediately acquire an exclusive lock on
//                                      the database. No other reads or writes
//                                      will be allowed.
//
typedef enum : NSInteger {
	FRZStoreTransactionTypeDeferred,
	FRZStoreTransactionTypeImmediate,
	FRZStoreTransactionTypeExclusive,
} FRZStoreTransactionType;

@class FMDatabase;

@interface FRZStore ()

// An array of changes which will be delivered after the current transaction has
// been committed.
- (NSMutableArray *)queuedChanges;

// Perform a transaction of the given type.
//
// Transactions may be nested. If an error occurs, then the entire and all
// parent transactions will be rolled back. Changes are only committed once all
// nested transaction have completed.
//
// transactionType - The type of transaction to perform.
// error           - The error if one occurs.
// block           - The block in which database actions can be performed.
//                   Cannot be nil.
- (BOOL)performTransactionType:(FRZStoreTransactionType)transactionType error:(NSError **)error block:(BOOL (^)(FMDatabase *database, NSError **error))block;

// Get the ID of the head transaction of the store.
//
// error - The error if one occurred.
//
// Returns the ID, or -1 if an error occurred.
- (long long int)headID:(NSError **)error;

@end
