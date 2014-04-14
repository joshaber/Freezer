//
//  FRZKeyLense+Private.h
//  Freezer
//
//  Created by Josh Abernathy on 4/3/14.
//  Copyright (c) 2014 Josh Abernathy. All rights reserved.
//

#import "FRZKeyLense.h"

@class FRZDatabase;
@class FRZStore;

@interface FRZKeyLense ()

- (id)initWithKey:(NSString *)key ID:(NSString *)ID database:(FRZDatabase *)database store:(FRZStore *)store;

@end
