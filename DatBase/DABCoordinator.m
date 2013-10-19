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
#import "FMDatabase.h"
#import "DABDatabasePool.h"

NSString * const DABRefsTableName = @"refs";
NSString * const DABEntitiesTableName = @"entities";
NSString * const DABTransactionsTableName = @"txs";
NSString * const DABTransactionToEntityTableName = @"tx_to_entity";

@interface DABCoordinator ()

@property (nonatomic, readonly, strong) DABDatabasePool *databasePool;

@property (nonatomic, readonly, strong) GTRepository *repository;

@end

@implementation DABCoordinator

- (id)initWithPath:(NSString *)path error:(NSError **)error {
	self = [super init];
	if (self == nil) return nil;

	_databasePool = [[DABDatabasePool alloc] initWithDatabaseAtPath:path];

	FMDatabase *database = [_databasePool databaseForCurrentThread:error];
	if (database == nil) return nil;

	return self;
}

- (id)initInMemory:(NSError **)error {
	return [self initWithPath:nil error:error];
}

- (id)initWithDatabaseAtURL:(NSURL *)URL error:(NSError **)error {
	NSParameterAssert(URL != nil);

	return [self initWithPath:URL.path error:error];
}

- (long long int)headID:(NSError **)error {
	long long int headID = 0;
	FMDatabase *database = [self.databasePool databaseForCurrentThread:error];
	if (database == nil) return -1;

	FMResultSet *set = [database executeQuery:@"SELECT tx_id from refs WHERE name = ? LIMIT 1", @"HEAD"];
	if ([set next]) {
		headID = [set longLongIntForColumnIndex:0];
	}

	return headID;
}

- (GTCommit *)HEADCommit:(NSError **)error {
	__block GTCommit *commit;

	[self performBlock:^(GTRepository *repository) {
		commit = [self.repository lookupObjectByRefspec:@"HEAD" error:error];
	}];

	return commit;
}

- (DABDatabase *)currentDatabase:(NSError **)error {
	long long int headID = [self headID:error];
	if (headID < 0) return nil;

	return [[DABDatabase alloc] initWithDatabasePool:self.databasePool transactionID:headID];
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
