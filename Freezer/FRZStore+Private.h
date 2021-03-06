//
//  FRZStore+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZStore.h"
#import <sqlite3.h>

// The head transaction ID key.
extern NSString * const FRZStoreHeadTransactionKey;

// The transaction date key.
extern NSString * const FRZStoreTransactionDateKey;

// The type of transaction to use.
//
//   FRZStoreTransactionTypeDeferred  - Defer lock acquisition until it is
//                                      needed.
//   FRZStoreTransactionTypeExclusive - Immediately acquire an exclusive lock on
//                                      the database. No other reads or writes
//                                      will be allowed.
//
typedef enum : NSInteger {
	FRZStoreTransactionTypeDeferred,
	FRZStoreTransactionTypeExclusive,
} FRZStoreTransactionType;

@class FMDatabase;

@interface FRZStore ()

// The database before the transaction began. This is only valid while in a
// transaction. Terrible things may happen if it's called outside a transaction.
@property (nonatomic, readonly, strong) FRZDatabase *databaseBeforeTransaction;

// An array of changes which will be delivered after the current transaction has
// been committed.
- (NSMutableArray *)queuedChanges;

// Get the ID of the head transaction of the store.
//
// Returns the ID.
- (long long int)headID;

// The number of entries in the store.
//
// Note that this is for the entire store, including transactions and other
// Freezer-specific data. This should only be used for testing and debugging.
//
// Returns the number of entries.
- (long long int)entryCount;

// Perform some reads within a transaction.
//
// error - The error if one occurred.
// block - The block in which reads will be done. Cannot be nil.
//
// Returns whether the reads were successful.
- (BOOL)performReadTransactionWithError:(NSError **)error block:(BOOL (^)(FMDatabase *database, NSError **error))block;

// Performs some writes within a transaction.
//
// error - The error if one occurred.
// block - The block in which writes will be done. Cannot be nil.
//
// Returns whether the writes were successful.
- (BOOL)performWriteTransactionWithError:(NSError **)error block:(BOOL (^)(FMDatabase *database, long long int txID, NSError **error))block;

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
- (BOOL)performTransactionType:(FRZStoreTransactionType)transactionType withNewTransaction:(BOOL)withNewTransaction error:(NSError **)error block:(BOOL (^)(FMDatabase *database, long long int txID, NSError **error))block;

// Execute the SQLite update statement.
//
// update   - The update query to run. Cannot be nil.
// database - The database on which the statement should be run. Cannot be nil.
// error    - The error if one occurred.
//
// Returns whether the query ran successfully.
- (BOOL)executeUpdate:(NSString *)update withDatabase:(FMDatabase *)database error:(NSError **)error;

// Get the database for the current thread.
//
// error - The error if one occurred.
//
// Returns the database or nil if an error occurred.
- (FMDatabase *)databaseForCurrentThread:(NSError **)error;

@end
