//
//  FRZDatabase+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZDatabase.h"

@class FRZCoordinator;

@interface FRZDatabase ()

- (id)initWithCoordinator:(FRZCoordinator *)coordinator transactionID:(long long int)transactionID;

@end
