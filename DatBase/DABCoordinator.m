//
//  DABCoordinator.m
//  DatBase
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "DABCoordinator.h"
#import "DABCoordinator+Private.h"
#import <ObjectiveGit/ObjectiveGit.h>
#import "DABDatabase+Private.h"
#import "DABTransactor+Private.h"

@interface DABCoordinator ()

@property (nonatomic, readonly, strong) GTRepository *repository;

@end

@implementation DABCoordinator

+ (instancetype)createDatabaseAtURL:(NSURL *)URL error:(NSError **)error {
	NSParameterAssert(URL != nil);

	GTRepository *repo = [GTRepository initializeEmptyRepositoryAtFileURL:URL bare:YES error:error];
	if (repo == nil) return nil;

	return [[self alloc] initWithDatabaseAtURL:URL error:error];
}

- (id)initWithDatabaseAtURL:(NSURL *)URL error:(NSError **)error {
	NSParameterAssert(URL != nil);

	self = [super init];
	if (self == nil) return nil;

	_repository = [[GTRepository alloc] initWithURL:URL error:error];
	if (_repository == nil) return nil;

	return self;
}

- (GTCommit *)HEADCommit:(NSError **)error {
	__block GTCommit *commit;

	[self performBlock:^(GTRepository *repository) {
		commit = [self.repository lookupObjectByRefspec:@"HEAD" error:error];
	}];

	return commit;
}

- (DABDatabase *)currentDatabase:(NSError **)error {
	GTCommit *commit = [self HEADCommit:error];
	return [[DABDatabase alloc] initWithCommit:commit];
}

- (void)performBlock:(void (^)(GTRepository *repository))block {
	NSParameterAssert(block != NULL);

	block(self.repository);
}

- (void)performAtomicBlock:(void (^)(GTRepository *repository))block {
	NSParameterAssert(block != NULL);

	@synchronized (self) {
		block(self.repository);
	}
}

- (DABTransactor *)transactor {
	return [[DABTransactor alloc] initWithCoordinator:self];
}

@end
