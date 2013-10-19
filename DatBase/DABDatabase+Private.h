//
//  DABDatabase+Private.h
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABDatabase.h"

@class DABDatabasePool;

@interface DABDatabase ()

- (id)initWithDatabasePool:(DABDatabasePool *)databasePool transactionID:(long long int)transactionID;

@end
