//
//  DABTransactor.h
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DABTransactor : NSObject

- (NSString *)generateNewKey;

- (BOOL)applyChangesWithError:(NSError **)error block:(BOOL (^)(NSError **error))block;

- (BOOL)addValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error;

- (BOOL)removeValueForAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error;

@end
