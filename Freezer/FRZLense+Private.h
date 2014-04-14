//
//  FRZLense+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 4/13/14.
//  Copyright (c) 2014 Josh Abernathy. All rights reserved.
//

#import "FRZLense.h"

@class FRZDatabase;
@class FRZStore;
@class FRZTransactor;

@interface FRZLense ()

- (id)initWithDatabase:(FRZDatabase *)database store:(FRZStore *)store removeBlock:(id (^)(id, FRZTransactor *, NSError **))removeBlock addBlock:(id (^)(id, FRZTransactor *, NSError **))addBlock readBlock:(id (^)(FRZDatabase *, NSError **))readBlock;

@end
