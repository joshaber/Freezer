//
//  FRZCoordinator.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FRZDatabase;
@class FRZTransactor;

@interface FRZCoordinator : NSObject

- (id)initInMemory:(NSError **)error;

- (id)initWithDatabaseAtURL:(NSURL *)URL error:(NSError **)error;

- (FRZDatabase *)currentDatabase:(NSError **)error;

- (FRZTransactor *)transactor;

@end
