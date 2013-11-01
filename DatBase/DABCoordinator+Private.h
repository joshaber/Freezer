//
//  DABCoordinator+Private.h
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABCoordinator.h"

extern NSString * const DABRefsTableName;
extern NSString * const DABEntitiesTableName;
extern NSString * const DABTransactionsTableName;
extern NSString * const DABTransactionToEntityTableName;

extern NSString * const DABHeadRefName;

@class FMDatabase;

@interface DABCoordinator ()

- (BOOL)performWithError:(NSError **)error block:(BOOL (^)(FMDatabase *database, NSError **error))block;

- (long long int)headID:(NSError **)error;

@end
