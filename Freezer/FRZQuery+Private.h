//
//  FRZQuery_Private.h
//  Freezer
//
//  Created by Josh Abernathy on 12/27/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZQuery.h"

@class FRZDatabase;

@interface FRZQuery ()

- (id)initWithDatabase:(FRZDatabase *)database queryStringBlock:(NSString * (^)(void))queryStringBlock;

@end
