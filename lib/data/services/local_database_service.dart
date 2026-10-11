import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/database_constants.dart';
import '../models/app_pref_model.dart';
import '../models/cached_listing_model.dart';
import '../models/cached_order_model.dart';
import '../models/draft_listing_model.dart';
import '../models/game_score_model.dart';

/// Service providing direct SQLite CRUD operations for Recovera's 5 local tables.
/// Follows Clean Architecture Data Layer guidelines: wraps SQLite driver and returns models.
class LocalDatabaseService {
  final AppDatabase _appDatabase;

  LocalDatabaseService({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase.instance;

  Future<Database> get _db => _appDatabase.database;

  // ===========================================================================
  // 1. cached_listings
  // ===========================================================================

  /// Upsert a single cached listing.
  Future<void> upsertListing(CachedListingModel listing) async {
    final db = await _db;
    await db.insert(
      DatabaseConstants.tableCachedListings,
      listing.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Bulk upsert listings inside a single batch transaction.
  Future<void> upsertListings(List<CachedListingModel> listings) async {
    if (listings.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final listing in listings) {
      batch.insert(
        DatabaseConstants.tableCachedListings,
        listing.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Query cached listings with offline search, filter, and sort capabilities per US-05.
  Future<List<CachedListingModel>> getListings({
    String? search,
    String? category,
    double? maxPrice,
    int? minDays,
    String? sort,
  }) async {
    final db = await _db;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    // Status filter - only active listings by default
    whereClauses.add('${DatabaseConstants.colListingStatus} = ?');
    whereArgs.add('active');

    // Search by product name or brand
    if (search != null && search.trim().isNotEmpty) {
      final term = '%${search.trim()}%';
      whereClauses.add(
        '(${DatabaseConstants.colListingProductName} LIKE ? OR ${DatabaseConstants.colListingBrand} LIKE ?)',
      );
      whereArgs.add(term);
      whereArgs.add(term);
    }

    // Category filter
    if (category != null && category.trim().isNotEmpty && category != 'All') {
      whereClauses.add('${DatabaseConstants.colListingCategory} = ?');
      whereArgs.add(category.trim());
    }

    // Max price filter
    if (maxPrice != null && maxPrice > 0) {
      whereClauses.add('${DatabaseConstants.colListingCurrentPrice} <= ?');
      whereArgs.add(maxPrice);
    }

    // Min days until expiry filter
    if (minDays != null && minDays > 0) {
      // Calculate target date: expiry_date >= today + minDays
      final minDate = DateTime.now().add(Duration(days: minDays)).toIso8601String().substring(0, 10);
      whereClauses.add('${DatabaseConstants.colListingExpiryDate} >= ?');
      whereArgs.add(minDate);
    }

    // Sorting
    String orderBy;
    switch (sort) {
      case 'cheapest':
        orderBy = '${DatabaseConstants.colListingCurrentPrice} ASC';
        break;
      case 'expiring':
        orderBy = '${DatabaseConstants.colListingExpiryDate} ASC';
        break;
      case 'nearest':
        orderBy = '${DatabaseConstants.colListingDistanceKm} ASC, ${DatabaseConstants.colListingId} DESC';
        break;
      default:
        orderBy = '${DatabaseConstants.colListingCreatedAt} DESC';
        break;
    }

    final maps = await db.query(
      DatabaseConstants.tableCachedListings,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: orderBy,
    );

    return maps.map((m) => CachedListingModel.fromMap(m)).toList();
  }

  Future<CachedListingModel?> getListingById(int id) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConstants.tableCachedListings,
      where: '${DatabaseConstants.colListingId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CachedListingModel.fromMap(maps.first);
  }

  Future<int> deleteListing(int id) async {
    final db = await _db;
    return await db.delete(
      DatabaseConstants.tableCachedListings,
      where: '${DatabaseConstants.colListingId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearListings() async {
    final db = await _db;
    await db.delete(DatabaseConstants.tableCachedListings);
  }

  Future<int> getListingsCount() async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableCachedListings}'),
    );
    return count ?? 0;
  }

  // ===========================================================================
  // 2. draft_listings (Offline Sync Queue)
  // ===========================================================================

  /// Insert a new draft listing into the local queue. Returns generated local id.
  Future<int> insertDraft(DraftListingModel draft) async {
    final db = await _db;
    return await db.insert(
      DatabaseConstants.tableDraftListings,
      draft.toMap(),
    );
  }

  Future<int> updateDraft(DraftListingModel draft) async {
    if (draft.id == null) {
      throw ArgumentError('Draft ID cannot be null when updating');
    }
    final db = await _db;
    return await db.update(
      DatabaseConstants.tableDraftListings,
      draft.toMap(),
      where: '${DatabaseConstants.colDraftId} = ?',
      whereArgs: [draft.id],
    );
  }

  Future<DraftListingModel?> getDraftById(int id) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConstants.tableDraftListings,
      where: '${DatabaseConstants.colDraftId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DraftListingModel.fromMap(maps.first);
  }

  Future<List<DraftListingModel>> getAllDrafts() async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConstants.tableDraftListings,
      orderBy: '${DatabaseConstants.colDraftCreatedAt} DESC',
    );
    return maps.map((m) => DraftListingModel.fromMap(m)).toList();
  }

  /// Get pending drafts that need to be uploaded to server once connectivity is restored.
  Future<List<DraftListingModel>> getPendingDrafts() async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConstants.tableDraftListings,
      where: '${DatabaseConstants.colDraftSyncStatus} = ?',
      whereArgs: [DatabaseConstants.syncStatusPending],
      orderBy: '${DatabaseConstants.colDraftCreatedAt} ASC',
    );
    return maps.map((m) => DraftListingModel.fromMap(m)).toList();
  }

  /// Update synchronization status and server listing reference.
  Future<int> updateDraftSyncStatus(
    int draftId,
    String status, {
    int? serverListingId,
    String? syncError,
  }) async {
    final db = await _db;
    final values = <String, dynamic>{
      DatabaseConstants.colDraftSyncStatus: status,
      DatabaseConstants.colDraftUpdatedAt: DateTime.now().toIso8601String(),
    };
    if (serverListingId != null) {
      values[DatabaseConstants.colDraftServerListingId] = serverListingId;
    }
    if (syncError != null) {
      values[DatabaseConstants.colDraftSyncError] = syncError;
    } else if (status == DatabaseConstants.syncStatusSynced) {
      values[DatabaseConstants.colDraftSyncError] = null;
    }

    return await db.update(
      DatabaseConstants.tableDraftListings,
      values,
      where: '${DatabaseConstants.colDraftId} = ?',
      whereArgs: [draftId],
    );
  }

  Future<int> deleteDraft(int id) async {
    final db = await _db;
    return await db.delete(
      DatabaseConstants.tableDraftListings,
      where: '${DatabaseConstants.colDraftId} = ?',
      whereArgs: [id],
    );
  }

  /// Delete all successfully synchronized drafts from the local table.
  Future<int> clearSyncedDrafts() async {
    final db = await _db;
    return await db.delete(
      DatabaseConstants.tableDraftListings,
      where: '${DatabaseConstants.colDraftSyncStatus} = ?',
      whereArgs: [DatabaseConstants.syncStatusSynced],
    );
  }

  Future<int> getDraftCount({String? status}) async {
    final db = await _db;
    if (status != null) {
      final count = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseConstants.tableDraftListings} WHERE ${DatabaseConstants.colDraftSyncStatus} = ?',
          [status],
        ),
      );
      return count ?? 0;
    }
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableDraftListings}'),
    );
    return count ?? 0;
  }

  // ===========================================================================
  // 3. cached_orders
  // ===========================================================================

  Future<void> upsertOrder(CachedOrderModel order) async {
    final db = await _db;
    await db.insert(
      DatabaseConstants.tableCachedOrders,
      order.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertOrders(List<CachedOrderModel> orders) async {
    if (orders.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final order in orders) {
      batch.insert(
        DatabaseConstants.tableCachedOrders,
        order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CachedOrderModel>> getOrders({int? buyerId, String? status}) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (buyerId != null) {
      whereClauses.add('${DatabaseConstants.colOrderBuyerId} = ?');
      whereArgs.add(buyerId);
    }
    if (status != null && status.isNotEmpty) {
      whereClauses.add('${DatabaseConstants.colOrderStatus} = ?');
      whereArgs.add(status);
    }

    final maps = await db.query(
      DatabaseConstants.tableCachedOrders,
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '${DatabaseConstants.colOrderCreatedAt} DESC',
    );
    return maps.map((m) => CachedOrderModel.fromMap(m)).toList();
  }

  Future<CachedOrderModel?> getOrderById(int id) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConstants.tableCachedOrders,
      where: '${DatabaseConstants.colOrderId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CachedOrderModel.fromMap(maps.first);
  }

  Future<int> deleteOrder(int id) async {
    final db = await _db;
    return await db.delete(
      DatabaseConstants.tableCachedOrders,
      where: '${DatabaseConstants.colOrderId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearOrders() async {
    final db = await _db;
    await db.delete(DatabaseConstants.tableCachedOrders);
  }

  // ===========================================================================
  // 4. game_scores
  // ===========================================================================

  Future<int> insertScore(GameScoreModel score) async {
    final db = await _db;
    return await db.insert(
      DatabaseConstants.tableGameScores,
      score.toMap(),
    );
  }

  Future<List<GameScoreModel>> getTopScores({int limit = 10}) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConstants.tableGameScores,
      orderBy: '${DatabaseConstants.colGameScore} DESC, ${DatabaseConstants.colGameItemsSaved} DESC',
      limit: limit,
    );
    return maps.map((m) => GameScoreModel.fromMap(m)).toList();
  }

  Future<List<GameScoreModel>> getRecentScores({int limit = 20}) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConstants.tableGameScores,
      orderBy: '${DatabaseConstants.colGamePlayedAt} DESC',
      limit: limit,
    );
    return maps.map((m) => GameScoreModel.fromMap(m)).toList();
  }

  Future<int> getTotalItemsSaved() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT SUM(${DatabaseConstants.colGameItemsSaved}) as total FROM ${DatabaseConstants.tableGameScores}',
    );
    if (result.isEmpty || result.first['total'] == null) return 0;
    return (result.first['total'] as num).toInt();
  }

  Future<void> clearScores() async {
    final db = await _db;
    await db.delete(DatabaseConstants.tableGameScores);
  }

  // ===========================================================================
  // 5. app_prefs
  // ===========================================================================

  Future<void> setPref(String key, String value) async {
    final db = await _db;
    final pref = AppPrefModel.create(key, value);
    await db.insert(
      DatabaseConstants.tableAppPrefs,
      pref.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getPref(String key) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConstants.tableAppPrefs,
      where: '${DatabaseConstants.colPrefKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first[DatabaseConstants.colPrefValue] as String?;
  }

  Future<int> deletePref(String key) async {
    final db = await _db;
    return await db.delete(
      DatabaseConstants.tableAppPrefs,
      where: '${DatabaseConstants.colPrefKey} = ?',
      whereArgs: [key],
    );
  }

  Future<Map<String, String>> getAllPrefs() async {
    final db = await _db;
    final maps = await db.query(DatabaseConstants.tableAppPrefs);
    final result = <String, String>{};
    for (final row in maps) {
      final key = row[DatabaseConstants.colPrefKey] as String;
      final value = row[DatabaseConstants.colPrefValue] as String;
      result[key] = value;
    }
    return result;
  }

  Future<void> clearPrefs() async {
    final db = await _db;
    await db.delete(DatabaseConstants.tableAppPrefs);
  }
}
