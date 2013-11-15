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

- (BOOL)addAttribute:(NSString *)attribute type:(FRZAttributeType)type collection:(BOOL)collection error:(NSError **)error {
	NSParameterAssert(attribute != nil);

	return [self addAttribute:attribute type:type collection:collection withMetadata:YES error:error];
}

- (BOOL)addAttribute:(NSString *)attribute type:(FRZAttributeType)type collection:(BOOL)collection withMetadata:(BOOL)withMetadata error:(NSError **)error {
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

	return [self.store performTransactionType:FRZStoreTransactionTypeExclusive withNewTransaction:withMetadata error:error block:^(FMDatabase *database, long long txID, NSError **error) {
		BOOL success = [self createTableWithName:tableName sqliteType:sqliteType database:database error:error];
		if (!success) return NO;

		if (database.changes < 1) return YES;
		if (!withMetadata) return YES;

		success = [self insertIntoDatabase:database value:@(type) forAttribute:FRZStoreAttributeTypeAttribute key:attribute transactionID:txID error:error];
		if (!success) return NO;

		return [self insertIntoDatabase:database value:@(collection) forAttribute:FRZStoreAttributeIsCollectionAttribute key:attribute transactionID:txID error:error];
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
	return [@"user/" stringByAppendingString:[[NSUUID UUID] UUIDString]];
}

- (BOOL)performChangesWithError:(NSError **)error block:(BOOL (^)(NSError **error))block {
	NSParameterAssert(block != NULL);

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		return block(error);
	}];
}

- (NSError *)invalidAttributeErrorWithError:(NSError *)error {
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	userInfo[NSLocalizedDescriptionKey] = NSLocalizedString(@"Invalid attribute", @"");
	if (error != nil) userInfo[NSUnderlyingErrorKey] = error;
	return [NSError errorWithDomain:FRZErrorDomain code:FRZErrorInvalidAttribute userInfo:userInfo];
}

- (NSString *)insertQueryForAttribute:(NSString *)attribute {
	static dispatch_once_t onceToken;
	static NSMutableDictionary *lookup;
	static dispatch_queue_t queue;
	dispatch_once(&onceToken, ^{
		lookup = [NSMutableDictionary dictionary];
		queue = dispatch_queue_create("blah", 0);
	});

	__block NSString *query;
	dispatch_sync(queue, ^{
		query = lookup[attribute];
		if (query != nil) return;

		NSString *tableName = [self.store tableNameForAttribute:attribute];
		query = [NSString stringWithFormat:@"INSERT INTO %@ (attribute, value, key, tx_id) VALUES (?, ?, ?, ?)", tableName];
		lookup[attribute] = query;
	});

	return query;
}

- (BOOL)insertIntoDatabase:(FMDatabase *)database value:(id)value forAttribute:(NSString *)attribute key:(NSString *)key transactionID:(long long int)transactionID error:(NSError **)error {
	NSParameterAssert(database != nil);
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	NSString *query = [self insertQueryForAttribute:attribute];
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

	BOOL success = [self insertIntoDatabase:database value:[NSDate date] forAttribute:FRZStoreTransactionDateAttribute key:@"head" transactionID:0 error:error];
	if (!success) return -1;

	return database.lastInsertRowId;
}

- (BOOL)addValue:(id)value forAttribute:(NSString *)attribute key:(NSString *)key error:(NSError **)error {
	NSParameterAssert(value != nil);
	NSParameterAssert(attribute != nil);
	NSParameterAssert(key != nil);

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		BOOL isCollection = [self.store.databaseBeforeTransaction isCollectionAttribute:attribute];
		if (isCollection) {
			NSString *newKey = [self generateNewKey];
			BOOL success = [self insertIntoDatabase:database value:value forAttribute:attribute key:newKey transactionID:txID error:error];
			if (!success) return NO;

			success = [self insertIntoDatabase:database value:key forAttribute:FRZStoreAttributeParentAttribute key:newKey transactionID:txID error:error];
			if (!success) return NO;
		} else {
			BOOL success = [self insertIntoDatabase:database value:value forAttribute:attribute key:key transactionID:txID error:error];
			if (!success) return NO;
		}

		[self.store.queuedChanges addObject:[[FRZChange alloc] initWithType:FRZChangeTypeAdd key:key attribute:attribute delta:value]];

		return YES;
	}];
}

- (BOOL)updateHeadInDatabase:(FMDatabase *)database toID:(long long int)ID error:(NSError **)error {
	NSParameterAssert(database != nil);

	return [self insertIntoDatabase:database value:@(ID) forAttribute:FRZStoreHeadTransactionAttribute key:@"head" transactionID:0 error:error];
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

	return [self.store performWriteTransactionWithError:error block:^(FMDatabase *database, long long txID, NSError **error) {
		FRZDatabase *previousDatabase = self.store.databaseBeforeTransaction;
		BOOL isCollection = [previousDatabase isCollectionAttribute:attribute];
		id currentValue = [previousDatabase valueForKey:key attribute:attribute];
		
		BOOL validRemoval = NO;
		if (isCollection) {
			validRemoval = [currentValue containsObject:value];
		} else {
			validRemoval = [currentValue isEqual:value];
		}

		if (!validRemoval) {
			NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"", @"") };
			if (error != NULL) *error = [NSError errorWithDomain:FRZErrorDomain code:FRZErrorInvalidValue userInfo:userInfo];
			return NO;
		}

		BOOL success = [self insertIntoDatabase:database value:NSNull.null forAttribute:attribute key:key transactionID:txID error:error];
		if (!success) return NO;

		[self.store.queuedChanges addObject:[[FRZChange alloc] initWithType:FRZChangeTypeRemove key:key attribute:attribute delta:value]];

		return YES;
	}];
}

#pragma mark Trimming

- (NSString *)placeholderWithCount:(NSUInteger)placeholderCount {
	NSMutableString *placeholder = [NSMutableString string];
	for (NSUInteger i = 0; i < placeholderCount; i++) {
		if (i == 0) {
			[placeholder appendString:@"?"];
		} else {
			[placeholder appendString:@", ?"];
		}
	}

	return placeholder;
}

- (BOOL)trimOldKeys:(FMDatabase *)database error:(NSError **)error {
	// 1. Get all the keys in the head of the database.
	// 2. Delete any entries with a key not in that set.
	FRZDatabase *currentDatabase = self.store.databaseBeforeTransaction;
	NSArray *keys = currentDatabase.allKeys.allObjects;
	for (NSString *attribute in currentDatabase.allAttributes) {
		NSString *tableName = [self.store tableNameForAttribute:attribute];
		NSString *query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE key NOT IN (%@)", tableName, [self placeholderWithCount:keys.count]];
		BOOL success = [database executeUpdate:query withArgumentsInArray:keys];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}
	}

	return YES;
}

- (BOOL)trimOldValues:(FMDatabase *)database error:(NSError **)error {
	// 1. Get the IDs for all the latest values for the keys.
	// 2. Delete any entries with an ID not in that set.
	FRZDatabase *currentDatabase = self.store.databaseBeforeTransaction;
	for (NSString *attribute in currentDatabase.allAttributes) {
		NSString *tableName = [self.store tableNameForAttribute:attribute];
		NSString *query = [NSString stringWithFormat:@"SELECT id FROM %@ GROUP BY key ORDER BY tx_id DESC", tableName];
		FMResultSet *set = [database executeQuery:query];
		if (set == nil) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}

		NSMutableArray *IDs = [NSMutableArray array];
		while ([set next]) {
			id ID = [set objectForColumnIndex:0];
			[IDs addObject:ID];
		}

		NSString *deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE id NOT IN (%@)", tableName, [self placeholderWithCount:IDs.count]];
		BOOL success = [database executeUpdate:deleteQuery withArgumentsInArray:IDs];
		if (!success) {
			if (error != NULL) *error = database.lastError;
			return NO;
		}
	}

	return YES;
}

- (BOOL)deleteEverythingButTheLastIDWithTableName:(NSString *)tableName database:(FMDatabase *)database error:(NSError **)error {
	NSString *query = [NSString stringWithFormat:@"SELECT id FROM %@ ORDER BY id DESC LIMIT 1", tableName];
	FMResultSet *set = [database executeQuery:query];
	if (set == nil) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	if (![set next]) return YES;

	NSString *headID = [set objectForColumnIndex:0];
	NSString *deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE id != ?", tableName];
	BOOL success = [database executeUpdate:deleteQuery, headID];
	if (!success) {
		if (error != NULL) *error = database.lastError;
		return NO;
	}

	return YES;
}

- (BOOL)trimOldTransactions:(FMDatabase *)database error:(NSError **)error {
	NSString *tableName = [self.store tableNameForAttribute:FRZStoreTransactionDateAttribute];
	BOOL success = [self deleteEverythingButTheLastIDWithTableName:tableName database:database error:error];
	if (!success) return NO;

	tableName = [self.store tableNameForAttribute:FRZStoreHeadTransactionAttribute];
	return [self deleteEverythingButTheLastIDWithTableName:tableName database:database error:error];
}

- (BOOL)trim:(NSError **)error {
	return [self.store performTransactionType:FRZStoreTransactionTypeExclusive withNewTransaction:NO error:error block:^(FMDatabase *database, long long txID, NSError **error) {
		BOOL success = [self trimOldKeys:database error:error];
		if (!success) return NO;

		success = [self trimOldValues:database error:error];
		if (!success) return NO;

		return [self trimOldTransactions:database error:error];
	}];
}

@end
