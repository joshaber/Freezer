//
//  FRZDeletedSentinel.m
//  Freezer
//
//  Created by Josh Abernathy on 3/3/14.
//  Copyright (c) 2014 Josh Abernathy. All rights reserved.
//

#import "FRZDeletedSentinel.h"

@implementation FRZDeletedSentinel

#pragma mark Lifecycle

+ (instancetype)deletedSentinel {
	static dispatch_once_t onceToken;
	static FRZDeletedSentinel *instance;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
	});

	return instance;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
	return self.class.deletedSentinel;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	// Nothing. The only important thing is the type itself.
}

@end
