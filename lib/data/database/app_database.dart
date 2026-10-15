import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'database_constants.dart';

/// Database helper singleton responsible for opening and managing SQLite database lifecycle.
/// Supports dependency injection for testing via [setTestDatabase].
class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal();

  Database? _database;

  /// Allow injecting a mock or in-memory Database for testing.
  void setTestDatabase(Database db) {
    _database = db;
  }

  /// Reset the database instance (useful for clean tear downs in test suites).
  Future<void> reset() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
  }

  /// Get the active Database handle, opening it if not yet initialized.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, DatabaseConstants.databaseName);

    return await openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onCreate: createTables,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create all five SQLite tables per PRD US-12 and docs/recovera-database-schema.md.
  /// Made public static so in-memory databases in unit tests can initialize schema easily.
  static Future<void> createTables(Database db, int version) async {
    final batch = db.batch();

    // 1. cached_listings
    batch.execute('''
      CREATE TABLE ${DatabaseConstants.tableCachedListings} (
        ${DatabaseConstants.colListingId} INTEGER PRIMARY KEY,
        ${DatabaseConstants.colListingProductId} INTEGER NOT NULL,
        ${DatabaseConstants.colListingSellerId} INTEGER NOT NULL,
        ${DatabaseConstants.colListingBatchNumber} TEXT NOT NULL,
        ${DatabaseConstants.colListingQty} INTEGER NOT NULL,
        ${DatabaseConstants.colListingNormalPrice} REAL NOT NULL,
        ${DatabaseConstants.colListingStartPrice} REAL NOT NULL,
        ${DatabaseConstants.colListingMinPrice} REAL NOT NULL,
        ${DatabaseConstants.colListingCurrentPrice} REAL NOT NULL,
        ${DatabaseConstants.colListingDropIntervalMinutes} INTEGER NOT NULL DEFAULT 60,
        ${DatabaseConstants.colListingDropPercentage} REAL NOT NULL DEFAULT 2.50,
        ${DatabaseConstants.colListingExpiryDate} TEXT NOT NULL,
        ${DatabaseConstants.colListingAuctionStartAt} TEXT NOT NULL,
        ${DatabaseConstants.colListingAuctionEndAt} TEXT NOT NULL,
        ${DatabaseConstants.colListingStatus} TEXT NOT NULL DEFAULT 'active',
        ${DatabaseConstants.colListingCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colListingProductName} TEXT NOT NULL,
        ${DatabaseConstants.colListingBrand} TEXT,
        ${DatabaseConstants.colListingCategory} TEXT NOT NULL,
        ${DatabaseConstants.colListingStorageType} TEXT NOT NULL DEFAULT 'ambient',
        ${DatabaseConstants.colListingDefaultUnit} TEXT NOT NULL DEFAULT 'pcs',
        ${DatabaseConstants.colListingImageUrl} TEXT,
        ${DatabaseConstants.colListingSellerCompany} TEXT,
        ${DatabaseConstants.colListingWarehouseLat} REAL,
        ${DatabaseConstants.colListingWarehouseLng} REAL,
        ${DatabaseConstants.colListingWarehouseCity} TEXT,
        ${DatabaseConstants.colListingDistanceKm} REAL,
        ${DatabaseConstants.colListingCachedAt} TEXT NOT NULL
      );
    ''');
    batch.execute('''
      CREATE INDEX idx_cached_listings_category
      ON ${DatabaseConstants.tableCachedListings} (${DatabaseConstants.colListingCategory});
    ''');
    batch.execute('''
      CREATE INDEX idx_cached_listings_product_name
      ON ${DatabaseConstants.tableCachedListings} (${DatabaseConstants.colListingProductName});
    ''');
    batch.execute('''
      CREATE INDEX idx_cached_listings_status
      ON ${DatabaseConstants.tableCachedListings} (${DatabaseConstants.colListingStatus});
    ''');

    // 2. draft_listings
    batch.execute('''
      CREATE TABLE ${DatabaseConstants.tableDraftListings} (
        ${DatabaseConstants.colDraftId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colDraftProductId} INTEGER,
        ${DatabaseConstants.colDraftProductName} TEXT NOT NULL,
        ${DatabaseConstants.colDraftBrand} TEXT,
        ${DatabaseConstants.colDraftCategory} TEXT NOT NULL,
        ${DatabaseConstants.colDraftStorageType} TEXT NOT NULL DEFAULT 'ambient',
        ${DatabaseConstants.colDraftDefaultUnit} TEXT NOT NULL DEFAULT 'pcs',
        ${DatabaseConstants.colDraftBatchNumber} TEXT NOT NULL,
        ${DatabaseConstants.colDraftQty} INTEGER NOT NULL,
        ${DatabaseConstants.colDraftNormalPrice} REAL NOT NULL,
        ${DatabaseConstants.colDraftStartPrice} REAL,
        ${DatabaseConstants.colDraftMinPrice} REAL NOT NULL,
        ${DatabaseConstants.colDraftDropIntervalMinutes} INTEGER NOT NULL DEFAULT 60,
        ${DatabaseConstants.colDraftDropPercentage} REAL NOT NULL DEFAULT 2.50,
        ${DatabaseConstants.colDraftExpiryDate} TEXT NOT NULL,
        ${DatabaseConstants.colDraftAuctionStartAt} TEXT,
        ${DatabaseConstants.colDraftAuctionEndAt} TEXT,
        ${DatabaseConstants.colDraftLocalImagePath} TEXT,
        ${DatabaseConstants.colDraftSyncStatus} TEXT NOT NULL DEFAULT '${DatabaseConstants.syncStatusPending}',
        ${DatabaseConstants.colDraftServerListingId} INTEGER,
        ${DatabaseConstants.colDraftSyncError} TEXT,
        ${DatabaseConstants.colDraftCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colDraftUpdatedAt} TEXT NOT NULL
      );
    ''');
    batch.execute('''
      CREATE INDEX idx_draft_listings_sync_status
      ON ${DatabaseConstants.tableDraftListings} (${DatabaseConstants.colDraftSyncStatus});
    ''');

    // 3. cached_orders
    batch.execute('''
      CREATE TABLE ${DatabaseConstants.tableCachedOrders} (
        ${DatabaseConstants.colOrderId} INTEGER PRIMARY KEY,
        ${DatabaseConstants.colOrderListingId} INTEGER NOT NULL,
        ${DatabaseConstants.colOrderBuyerId} INTEGER NOT NULL,
        ${DatabaseConstants.colOrderQty} INTEGER NOT NULL,
        ${DatabaseConstants.colOrderFinalUnitPrice} REAL NOT NULL,
        ${DatabaseConstants.colOrderTotalPrice} REAL NOT NULL,
        ${DatabaseConstants.colOrderStatus} TEXT NOT NULL DEFAULT 'paid',
        ${DatabaseConstants.colOrderCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colOrderProductName} TEXT NOT NULL,
        ${DatabaseConstants.colOrderCategory} TEXT NOT NULL,
        ${DatabaseConstants.colOrderBatchNumber} TEXT NOT NULL,
        ${DatabaseConstants.colOrderWarehouseLat} REAL,
        ${DatabaseConstants.colOrderWarehouseLng} REAL,
        ${DatabaseConstants.colOrderWarehouseAddress} TEXT,
        ${DatabaseConstants.colOrderCachedAt} TEXT NOT NULL
      );
    ''');
    batch.execute('''
      CREATE INDEX idx_cached_orders_status
      ON ${DatabaseConstants.tableCachedOrders} (${DatabaseConstants.colOrderStatus});
    ''');
    batch.execute('''
      CREATE INDEX idx_cached_orders_buyer
      ON ${DatabaseConstants.tableCachedOrders} (${DatabaseConstants.colOrderBuyerId});
    ''');

    // 4. game_scores
    batch.execute('''
      CREATE TABLE ${DatabaseConstants.tableGameScores} (
        ${DatabaseConstants.colGameId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colGameScore} INTEGER NOT NULL,
        ${DatabaseConstants.colGameItemsSaved} INTEGER NOT NULL,
        ${DatabaseConstants.colGameBadge} TEXT,
        ${DatabaseConstants.colGamePlayedAt} TEXT NOT NULL
      );
    ''');
    batch.execute('''
      CREATE INDEX idx_game_scores_score
      ON ${DatabaseConstants.tableGameScores} (${DatabaseConstants.colGameScore});
    ''');
    batch.execute('''
      CREATE INDEX idx_game_scores_played_at
      ON ${DatabaseConstants.tableGameScores} (${DatabaseConstants.colGamePlayedAt});
    ''');

    // 5. app_prefs
    batch.execute('''
      CREATE TABLE ${DatabaseConstants.tableAppPrefs} (
        ${DatabaseConstants.colPrefKey} TEXT PRIMARY KEY,
        ${DatabaseConstants.colPrefValue} TEXT NOT NULL,
        ${DatabaseConstants.colPrefUpdatedAt} TEXT NOT NULL
      );
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration logic for future schema increments
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
