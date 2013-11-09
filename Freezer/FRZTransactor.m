//
//  FRZTransactor.m
//  Freezer
//
//  Created by Josh Abernathy on 10/9/13.
//  Copyright (c) 2013 Josh Abernathy. All rights reserved.
//

#import "FRZTransactor.h"
#import "FRZDatabase+Private.h"
#import "FRZStore.h"
#import "FRZStore+Private.h"
#import "FMDatabase.h"
#import "FRZChange+Private.h"
#import "FRZSingleKeyTransactor+Private.h"

@interface FRZTransactor ()

@property (nonatomic, readonly, strong) FRZStore *store;

@end

@implementation FRZTransactor

#pragma mark Lifecycle

- (id)initWithStore:(FRZStore *)store {
	NSParameterAssert(store != nil);

	self = [super init];
	if (self == nil) return nil;

	_store = store;

	return self;
}

#pragma mark Attributes

- (BOOL)addAttribute:(NSString *)attribute type:(FRZAttributeType)type error:(NSError **)error {
	NSParameterAssert(attribute != nil);

	return [self addAttribute:attribute type:type withMetadata:YES error:error];
}

- (BOOL)addAttribute:(NSString *)attribute type:(FRZAttributeType)type withMetadata:(BOOL)withMetadata error:(NSError **)error {
	NSParameterAssert(attribute != nil);

	NSDictionary *typeToSqliteTypeName = @{
		@(FRZAttributeTypeInteger): @"INTEGER",
		@(FRZAttributeTypeReal): @"REAL",
		@(FRZAttributeTypeString): @"TEXT",
		@(FRZAttributeTypeBlob): @"BLOB",
		@(FRZAttributeTypeDate): @"DATETIME",
		@(FRZAttributeTypeRef): @"TEXT",
	};

	NSString *sqliteType = typeToSqliteTypeName[@(type)];
	NSAssert(sqliteType != nil, @"Unknown type: %ld", type);

	NSString *tableName = [self.store tableNameForAttribute:attribute];
	NSAssert(tableName != nil, @"No table name for attribute: %@", attribute);

	return [self.store performTransactionType:FRZStoreTransactionTypeExclusive error:error block:^(FMDatabase *database, NSError **error) {
		BOOL success = [self createTableWithName:tableName sqliteType:sqliteType database:database error:error];
		if (!success) return NO;

		if (!withMetadata) return YES;

		// TODO: Do we want to associate attributes with a tx?
		success = [self insertIntoDatabase:database value:@(type) forAttribute:FRZStoreAttributeTypeAttribute key:attribute transactionID:0 error:error];
		if (!success) return NO;

		return YES;
	}];
}

- (BOOL)createTableWithName:(NSString *)name sqliteType:(NSString *)sqliteType database:(FMDatabase *)database error:(NSError **)error {
	NSParameterAssert(name != nil);
	NSParameterAssert(sqliteType != nil);
	NSParameterAssert(database != nil);

	NSString *schemaTemplate =
		@"CREATE TABLE IF NOT EXISTS %@("
		"id INTEGER PRIMARY KEY AUTOINCREMENT,"
		"key STRING NOT NULL,"
		"attribute STRING NOT NULL,"
		"value %@,"
		"tx_id INTEGER NOT NULL"
	");";

	NSString *schema = [NSString stringWithFormat:schemaTemplate, name, sqliteType];
	BOOL success = [database executeUpdate:schema];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}
	
	return YES;
}

#pragma mark Changing

- (NSString *)generateNewKey {
	// Problem?
	return [NSString stringWithFormat:@"user/%@", [[NSUUID UUID] UUIDString]];
}

- (BOOL)performChangesWithError:(NSError **)error block:(BOOL (^)(NSError **error))block {
	NSParameterAssert(block != NULL);

	return [self.store performTransactionType:FRZStoreTransactionTypeExclusive error:error block:^(FMDatabase *database, NSError **error) {
		return block(error);
	}];
}

- (NSError *)invalidAttributeErrorWithError:(NSError *)error {
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	userInfo[NSLocalizedDescriptionKey] = NSLocalizedString(@"Invalid attribute", @"");
	if (error != nil) userInfo[NSUnderlyingErrorKey] = error;
	return [NSError errorWithDomain:FRZErrorDomain code:FRZErrorInvalidAttribute userInfo:userInfo];
}

- (BOOL)insertIntoDatabase:(FMDatabase *)database value:(id)value forAttribute:(NSString *)attribute key:(NSString *)key transactionID:(long long int)transactionID error:(NSError **)error {
	NSParameterAssert(database != nil);
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	NSString *tableName = [self.store tableNameForAttribute:attribute];
	NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ (attribute, value, key, tx_id) VALUES (?, ?, ?, ?)", tableName];
	BOOL success = [database executeUpdate:query, attribute, value, key, @(transactionID)];
	if (!success) {
		// We're really just guessing that the error is invalid attribute. FMDB
		// doesn't wrap errors in any meaningful way.
		if (error != NULL) *error = [self invalidAttributeErrorWithError:database.lastError];
		return NO;
	}

	return YES;
}

- (long long int)insertNewTransactionIntoDatabase:(FMDatabase *)database error:(NSError **)error {
	NSParameterAssert(database != nil);

	long long int headID = [self.store headID:error];
	BOOL success = [self insertIntoDatabase:database value:[NSDate date] forAttribute:FRZStoreTransactionDateAttribute key:@"head" transactionID:headID error:error];
	if (!success) return -1;

	return database.lastInsertRowId;
}

- (BOOL)addValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	// We could split some of this work out into a non-exclusive transaction,
	// but by batching it all in a single transaction we get a much higher write
	// speed. (~370 w/s vs. ~600 w/s on my computer).
	//
	// TODO: Test whether the write cost of splitting it up is made up in read
	// speed.
	return [self.store performTransactionType:FRZStoreTransactionTypeExclusive error:error block:^(FMDatabase *database, NSError **error) {
		sqlite_int64 txID = [self insertNewTransactionIntoDatabase:database error:error];
		if (txID < 0) return NO;

		BOOL success = [self insertIntoDatabase:database value:value forAttribute:attribute key:key transactionID:txID error:error];
		if (!success) return NO;

		[self.store.queuedChanges addObject:[[FRZChange alloc] initWithType:FRZChangeTypeAdd key:key attribute:attribute delta:value]];

		return [self updateHeadInDatabase:database toID:txID error:error];
	}];
}

- (BOOL)addValuesWithKey:(NSString *)key error:(NSError **)error block:(BOOL (^)(FRZSingleKeyTransactor *transactor, NSError **error))block {
	NSParameterAssert(key != nil);
	NSParameterAssert(block != NULL);

	FRZSingleKeyTransactor *transactor = [[FRZSingleKeyTransactor alloc] initWithTransactor:self key:key];
	return [self performChangesWithError:error block:^(NSError **error) {
		return block(transactor, error);
	}];
}

- (BOOL)removeValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	return [self.store performTransactionType:FRZStoreTransactionTypeExclusive error:error block:^(FMDatabase *database, NSError **error) {
		FRZDatabase *previousDatabase = [self.store currentDatabase];
		id currentValue = [previousDatabase valueForKey:key attribute:attribute];
		if (![currentValue isEqual:value]) {
			NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"", @"") };
			if (error != NULL) *error = [NSError errorWithDomain:FRZErrorDomain code:FRZErrorInvalidValue userInfo:userInfo];
			return NO;
		}

		sqlite_int64 txID = [self insertNewTransactionIntoDatabase:database error:error];
		if (txID < 0) return NO;

		BOOL success = [self insertIntoDatabase:database value:NSNull.null forAttribute:attribute key:key transactionID:txID error:error];
		if (!success) return NO;

		[self.store.queuedChanges addObject:[[FRZChange alloc] initWithType:FRZChangeTypeRemove key:key attribute:attribute delta:value]];

		return [self updateHeadInDatabase:database toID:txID error:error];
	}];
}

- (BOOL)updateHeadInDatabase:(FMDatabase *)database toID:(sqlite_int64)ID error:(NSError **)error {
	NSParameterAssert(database != nil);

	// TODO: Do we want to give head updates a transaction ID?
	return [self insertIntoDatabase:database value:@(ID) forAttribute:FRZStoreHeadTransactionAttribute key:@"head" transactionID:0 error:error];
}

@end
