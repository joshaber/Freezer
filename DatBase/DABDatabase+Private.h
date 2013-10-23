//
//  DABDatabase+Private.h
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABDatabase.h"

@class DABCoordinator;

@interface DABDatabase ()

- (id)initWithCoordinator:(DABCoordinator *)coordinator transactionID:(long long int)transactionID;

@end
