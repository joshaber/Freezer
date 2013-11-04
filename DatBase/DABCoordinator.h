//
//  DABCoordinator.h
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DABDatabase;
@class DABTransactor;

@interface DABCoordinator : NSObject

- (id)initInMemory:(NSError **)error;

- (id)initWithDatabaseAtURL:(NSURL *)URL error:(NSError **)error;

- (DABDatabase *)currentDatabase:(NSError **)error;

- (DABTransactor *)transactor;

@end
