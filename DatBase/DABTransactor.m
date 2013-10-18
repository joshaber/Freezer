//
//  DABTransactor.m
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABTransactor.h"
#import "DABDatabase+Private.h"
#import "DABCoordinator.h"
#import "DABCoordinator+Private.h"
#import <ObjectiveGit/ObjectiveGit.h>

@interface DABTransactor ()

@property (nonatomic, readonly, strong) DABCoordinator *coordinator;

@end

@implementation DABTransactor

- (id)initWithCoordinator:(DABCoordinator *)coordinator {
	NSParameterAssert(coordinator != nil);

	self = [super init];
	if (self == nil) return nil;

	_coordinator = coordinator;

	return self;
}

- (void)runTransaction:(void (^)(void))block {
	NSParameterAssert(block != NULL);

	[self.coordinator performBlock:^(GTRepository *repository) {
		block();
	}];
}

- (NSString *)generateNewKey {
	// Problem?
	return [[NSUUID UUID] UUIDString];
}

- (NSString *)addValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	__block NSString *ID;
	[self.coordinator performBlock:^(GTRepository *repository) {
		DABDatabase *database = [self.coordinator currentDatabase:error];
		if (database == nil) return;

		NSMutableDictionary *existingEntry = [database[key] mutableCopy] ?: [NSMutableDictionary dictionary];
		existingEntry[attribute] = value;
		NSData *data = [NSJSONSerialization dataWithJSONObject:existingEntry options:0 error:error];
		if (data == nil) return;

		GTCommit *commit = [self.coordinator HEADCommit:error];
		GTTreeBuilder *builder = [[GTTreeBuilder alloc] initWithTree:commit.tree error:error];
		if (builder == nil) return;

		GTTreeEntry *entry = [builder addEntryWithData:data fileName:key fileMode:GTFileModeBlob error:error];
		if (entry == nil) return;

		GTTree *tree = [builder writeTreeToRepository:repository error:error];
		if (tree == nil) return;

		GTSignature *signature = [[GTSignature alloc] initWithName:@"DatBase" email:@"dat@base.com" time:[NSDate date]];
		NSArray *parents = (commit != nil ? @[ commit ] : nil);
		GTCommit *newCommit = [repository createCommitWithTree:tree message:@"" author:signature committer:signature parents:parents updatingReferenceNamed:@"HEAD" error:error];
		if (newCommit == nil) return;

		ID = [key copy];
	}];

	return ID;
}

@end
