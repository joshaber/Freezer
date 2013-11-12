//
//  FRZStore+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZStore.h"
#import <sqlite3.h>

// The head transaction ID attribute.
extern NSString * const FRZStoreHeadTransactionAttribute;

// The transaction date attribute.
extern NSString * const FRZStoreTransactionDateAttribute;

// The attribute's type.
extern NSString * const FRZStoreAttributeTypeAttribute;

// Is the attribute a collection?
extern NSString * const FRZStoreAttributeIsCollectionAttribute;

// The key of the parent of the collection.
extern NSString * const FRZStoreAttributeParentAttribute;

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

// An array of changes which will be delivered after the current transaction has
// been committed.
- (NSMutableArray *)queuedChanges;

// Get the ID of the head transaction of the store.
//
// Returns the ID.
- (long long int)headID;

// Convert from an attribute name to the Sqlite table name.
//
// attribute - The Freezer attribute name. Cannot be nil.
//
// Returns the Sqlite table name.
- (NSString *)tableNameForAttribute:(NSString *)attribute;

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

@end
