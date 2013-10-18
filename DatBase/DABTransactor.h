//
//  DABTransactor.h
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DABObjectID;

@interface DABTransactor : NSObject

- (void)runTransaction:(void (^)(void))block;

- (NSString *)generateNewKey;

- (NSString *)addValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error;

@end
