//
//  DABDatabasePool.h
//  DatBase
//
//  Created by Josh Abernathy on 10/19/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FMDatabase;

@interface DABDatabasePool : NSObject

- (id)initWithDatabaseAtPath:(NSString *)path;

- (FMDatabase *)databaseForCurrentThread:(NSError **)error;

@end
