//
//  DABCoordinator+Private.h
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABCoordinator.h"

@class GTRepository;
@class GTCommit;

@interface DABCoordinator ()

- (GTCommit *)HEADCommit:(NSError **)error;

- (void)performBlock:(void (^)(GTRepository *repository))block;

- (void)performAtomicBlock:(void (^)(GTRepository *repository))block;

@end
