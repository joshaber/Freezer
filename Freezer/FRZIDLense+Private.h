//
//  FRZIDLense+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 4/3/14.
//  Copyright (c) 2014 Josh Abernathy. All rights reserved.
//

#import "FRZIDLense.h"

@class FRZDatabase;
@class FRZStore;

@interface FRZIDLense ()

- (id)initWithID:(NSString *)ID database:(FRZDatabase *)database store:(FRZStore *)store;

@end
