//
//  FRZDatabase.h
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FRZDatabase : NSObject

- (NSDictionary *)objectForKeyedSubscript:(NSString *)key;

- (NSArray *)allKeys;

- (NSArray *)keysWithAttribute:(NSString *)attribute error:(NSError **)error;

@end
