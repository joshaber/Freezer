//
//  DABDatabase.m
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABDatabase.h"
#import "DABDatabase+Private.h"
#import <ObjectiveGit/ObjectiveGit.h>

@interface DABDatabase ()

@property (nonatomic, readonly, strong) GTCommit *commit;

@end

@implementation DABDatabase

- (id)initWithCommit:(GTCommit *)commit {
	self = [super init];
	if (self == nil) return nil;

	_commit = commit;

	return self;
}

- (NSDictionary *)objectForKeyedSubscript:(NSString *)key {
	GTTreeEntry *entry = [self.commit.tree entryWithName:key];
	GTBlob *blob = (GTBlob *)[entry toObjectAndReturnError:NULL];
	if (blob == nil) return nil;

	return [NSJSONSerialization JSONObjectWithData:blob.data options:0 error:NULL];
}

- (NSArray *)allKeys {
	NSArray *contents = self.commit.tree.contents;
	NSMutableArray *keys = [NSMutableArray arrayWithCapacity:contents.count];
	for (GTTreeEntry *entry in contents) {
		[keys addObject:entry.name];
	}

	return keys;
}

@end
