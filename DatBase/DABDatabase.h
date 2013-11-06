//
//  DABDatabase.h
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DABDatabase : NSObject

- (NSDictionary *)objectForKeyedSubscript:(NSString *)key;

- (NSArray *)allKeys;

@end
