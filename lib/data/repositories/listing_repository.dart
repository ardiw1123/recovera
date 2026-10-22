import '../database/database_constants.dart';
import '../models/cached_listing_model.dart';
import '../models/draft_listing_model.dart';
import '../services/local_database_service.dart';

/// Contract for remote listing API client used by repository and sync queue.
abstract class RemoteListingClient {
  /// Fetch listings from backend API. Throws on network/server error.
  Future<List<CachedListingModel>> fetchRemoteListings({
    String? search,
    String? category,
    double? maxPrice,
    int? minDays,
    String? sort,
    double? lat,
    double? lng,
    double? radiusKm,
    int? page,
    int? limit,
  });

  /// Upload a draft listing to backend API. Returns created server listing ID.
  Future<int> uploadDraftListing(DraftListingModel draft);

  /// Fetch a single listing detail from backend API.
  Future<CachedListingModel?> fetchListingDetail(int id) async => null;
}

/// Result object wrapping listing query to indicate whether data is fresh or from SQLite cache.
/// Aligned with US-05: "Saat offline, listing tampil dari cache SQLite dengan indikator 'data cache'".
class ListingResult {
  final List<CachedListingModel> listings;
  final bool isFromCache;
  final String? errorMessage;

  const ListingResult({
    required this.listings,
    required this.isFromCache,
    this.errorMessage,
  });
}

/// Summary of an offline draft sync execution.
class DraftSyncResult {
  final int totalCount;
  final int syncedCount;
  final int failedCount;
  final List<String> errors;

  const DraftSyncResult({
    required this.totalCount,
    required this.syncedCount,
    required this.failedCount,
    required this.errors,
  });

  bool get isAllSynced => totalCount > 0 && failedCount == 0;
}

/// Repository managing listings and draft offline sync queue.
/// Follows PRD architecture: UI/Provider → ListingRepository → [Remote API | sqflite].
class ListingRepository {
  final LocalDatabaseService _localDb;
  final RemoteListingClient? remoteClient;

  ListingRepository({
    LocalDatabaseService? localDb,
    this.remoteClient,
  }) : _localDb = localDb ?? LocalDatabaseService();

  // ===========================================================================
  // Listings (Read & Cache)
  // ===========================================================================

  /// Get listings. When online and [forceRefresh] is true (or client available),
  /// attempts to fetch from remote and update SQLite cache.
  /// If offline or remote fails, falls back gracefully to `cached_listings` with isFromCache: true.
  Future<ListingResult> getListings({
    bool forceRefresh = false,
    String? search,
    String? category,
    double? maxPrice,
    int? minDays,
    String? sort,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    final client = remoteClient;
    // If remote client is configured and refresh requested, try fetching from network
    if (client != null && forceRefresh) {
      try {
        final remoteItems = await client.fetchRemoteListings(
          search: search,
          category: category,
          maxPrice: maxPrice,
          minDays: minDays,
          sort: sort,
          lat: lat,
          lng: lng,
          radiusKm: radiusKm,
        );

        // Update local cache
        try {
          await _localDb.upsertListings(remoteItems);
        } catch (_) {}

        return ListingResult(
          listings: remoteItems,
          isFromCache: false,
        );
      } catch (e) {
        // Fallback to SQLite cache on network failure
        try {
          final cachedItems = await _localDb.getListings(
            search: search,
            category: category,
            maxPrice: maxPrice,
            minDays: minDays,
            sort: sort,
          );
          if (cachedItems.isNotEmpty) {
            return ListingResult(
              listings: cachedItems,
              isFromCache: true,
              errorMessage: e.toString(),
            );
          }
        } catch (_) {}

        // Fallback ke demo listings saat offline / Web tanpa SQLite driver
        return ListingResult(
          listings: getDemoListings(
            search: search,
            category: category,
            radiusKm: radiusKm,
            minDays: minDays,
            sort: sort,
          ),
          isFromCache: true,
        );
      }
    }

    // Default: query local SQLite cache first (offline-first paradigm)
    try {
      final cached = await _localDb.getListings(
        search: search,
        category: category,
        maxPrice: maxPrice,
        minDays: minDays,
        sort: sort,
      );
      if (cached.isNotEmpty) {
        return ListingResult(listings: cached, isFromCache: true);
      }
    } catch (_) {}

    // If cache is empty and remote client is available, try fetching once
    if (client != null) {
      try {
        final remoteItems = await client.fetchRemoteListings(
          search: search,
          category: category,
          maxPrice: maxPrice,
          minDays: minDays,
          sort: sort,
          lat: lat,
          lng: lng,
          radiusKm: radiusKm,
        );
        try {
          await _localDb.upsertListings(remoteItems);
        } catch (_) {}
        return ListingResult(listings: remoteItems, isFromCache: false);
      } catch (_) {}
    }

    // Fallback default ke demo listings
    return ListingResult(
      listings: getDemoListings(
        search: search,
        category: category,
        radiusKm: radiusKm,
        minDays: minDays,
        sort: sort,
      ),
      isFromCache: true,
    );
  }

  /// Get a single listing by ID, checking remote detail if [forceRefresh] is true, else checking local cache first.
  Future<CachedListingModel?> getListingById(int id, {bool forceRefresh = false}) async {
    final client = remoteClient;
    if (client != null && forceRefresh) {
      try {
        final remoteDetail = await client.fetchListingDetail(id);
        if (remoteDetail != null) {
          try {
            await _localDb.upsertListings([remoteDetail]);
          } catch (_) {}
          return remoteDetail;
        }
      } catch (_) {}
    }

    try {
      final cached = await _localDb.getListingById(id);
      if (cached != null) return cached;
    } catch (_) {}

    if (client != null) {
      try {
        final remoteDetail = await client.fetchListingDetail(id);
        if (remoteDetail != null) {
          try {
            await _localDb.upsertListings([remoteDetail]);
          } catch (_) {}
          return remoteDetail;
        }
      } catch (_) {}
    }

    // Fallback cari di demo listings
    final demos = getDemoListings();
    try {
      return demos.firstWhere((l) => l.id == id);
    } catch (_) {
      return demos.isNotEmpty ? demos.first : null;
    }
  }

  /// Koleksi data lelang pangan demo untuk preview offline dan Flutter Web
  static List<CachedListingModel> getDemoListings({
    String? category,
    String? search,
    double? radiusKm,
    int? minDays,
    String? sort,
  }) {
    final now = DateTime.now();
    final items = [
      CachedListingModel(
        id: 101,
        productId: 1,
        sellerId: 10,
        batchNumber: 'BATCH-2026-UHT',
        qty: 120,
        normalPrice: 18000,
        startPrice: 12000,
        minPrice: 9000,
        currentPrice: 10800,
        dropIntervalMinutes: 30,
        dropPercentage: 2.5,
        expiryDate: now.add(const Duration(days: 7)).toIso8601String().substring(0, 10),
        auctionStartAt: now.subtract(const Duration(hours: 2)).toIso8601String(),
        auctionEndAt: now.add(const Duration(days: 3)).toIso8601String(),
        createdAt: now.subtract(const Duration(hours: 2)).toIso8601String(),
        cachedAt: now.toIso8601String(),
        productName: 'Susu UHT Full Cream 1L',
        brand: 'Ultra Milk',
        category: 'Dairy',
        storageType: 'ambient',
        defaultUnit: 'box',
        sellerCompany: 'PT Sumber Pangan Abadi',
        warehouseLat: -7.7058,
        warehouseLng: 110.6053,
        warehouseCity: 'Klaten',
        distanceKm: 2.4,
        matchScore: 94.5,
        discountPct: 40.0,
        daysToExpiry: 7,
      ),
      CachedListingModel(
        id: 102,
        productId: 2,
        sellerId: 10,
        batchNumber: 'BATCH-2026-TPG',
        qty: 350,
        normalPrice: 15000,
        startPrice: 10500,
        minPrice: 7500,
        currentPrice: 9000,
        dropIntervalMinutes: 45,
        dropPercentage: 3.0,
        expiryDate: now.add(const Duration(days: 14)).toIso8601String().substring(0, 10),
        auctionStartAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
        auctionEndAt: now.add(const Duration(days: 5)).toIso8601String(),
        createdAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
        cachedAt: now.toIso8601String(),
        productName: 'Tepung Terigu Segitiga Biru 1kg',
        brand: 'Bogasari',
        category: 'Flour & Grain',
        storageType: 'ambient',
        defaultUnit: 'kg',
        sellerCompany: 'PT Berkah Pangan Mandiri',
        warehouseLat: -7.7120,
        warehouseLng: 110.6100,
        warehouseCity: 'Klaten',
        distanceKm: 4.1,
        matchScore: 91.2,
        discountPct: 40.0,
        daysToExpiry: 14,
      ),
      CachedListingModel(
        id: 103,
        productId: 3,
        sellerId: 11,
        batchNumber: 'BATCH-2026-MYK',
        qty: 80,
        normalPrice: 38000,
        startPrice: 28000,
        minPrice: 22000,
        currentPrice: 24700,
        dropIntervalMinutes: 60,
        dropPercentage: 2.0,
        expiryDate: now.add(const Duration(days: 20)).toIso8601String().substring(0, 10),
        auctionStartAt: now.subtract(const Duration(hours: 8)).toIso8601String(),
        auctionEndAt: now.add(const Duration(days: 7)).toIso8601String(),
        createdAt: now.subtract(const Duration(hours: 8)).toIso8601String(),
        cachedAt: now.toIso8601String(),
        productName: 'Minyak Goreng Sawit 2L',
        brand: 'Bimoli',
        category: 'Oil',
        storageType: 'ambient',
        defaultUnit: 'box',
        sellerCompany: 'CV Distribusi Utama',
        warehouseLat: -7.6980,
        warehouseLng: 110.5980,
        warehouseCity: 'Klaten',
        distanceKm: 5.8,
        matchScore: 88.0,
        discountPct: 35.0,
        daysToExpiry: 20,
      ),
      CachedListingModel(
        id: 104,
        productId: 4,
        sellerId: 12,
        batchNumber: 'BATCH-2026-FROZ',
        qty: 50,
        normalPrice: 45000,
        startPrice: 32000,
        minPrice: 25000,
        currentPrice: 28000,
        dropIntervalMinutes: 30,
        dropPercentage: 4.0,
        expiryDate: now.add(const Duration(days: 5)).toIso8601String().substring(0, 10),
        auctionStartAt: now.subtract(const Duration(hours: 1)).toIso8601String(),
        auctionEndAt: now.add(const Duration(days: 2)).toIso8601String(),
        createdAt: now.subtract(const Duration(hours: 1)).toIso8601String(),
        cachedAt: now.toIso8601String(),
        productName: 'Sosis Sapi Premium 500g',
        brand: 'Bernardi',
        category: 'Frozen Food',
        storageType: 'frozen',
        defaultUnit: 'pack',
        sellerCompany: 'PT Cold Logistics Prima',
        warehouseLat: -7.7010,
        warehouseLng: 110.6020,
        warehouseCity: 'Klaten',
        distanceKm: 1.8,
        matchScore: 96.0,
        discountPct: 38.0,
        daysToExpiry: 5,
      ),
      CachedListingModel(
        id: 105,
        productId: 5,
        sellerId: 10,
        batchNumber: 'BATCH-2026-CHEESE',
        qty: 90,
        normalPrice: 24000,
        startPrice: 17000,
        minPrice: 13000,
        currentPrice: 15000,
        dropIntervalMinutes: 40,
        dropPercentage: 2.5,
        expiryDate: now.add(const Duration(days: 10)).toIso8601String().substring(0, 10),
        auctionStartAt: now.subtract(const Duration(hours: 3)).toIso8601String(),
        auctionEndAt: now.add(const Duration(days: 4)).toIso8601String(),
        createdAt: now.subtract(const Duration(hours: 3)).toIso8601String(),
        cachedAt: now.toIso8601String(),
        productName: 'Keju Cheddar Olahan 165g',
        brand: 'Kraft',
        category: 'Dairy',
        storageType: 'chilled',
        defaultUnit: 'box',
        sellerCompany: 'PT Sumber Pangan Abadi',
        warehouseLat: -7.7058,
        warehouseLng: 110.6053,
        warehouseCity: 'Klaten',
        distanceKm: 2.4,
        matchScore: 93.0,
        discountPct: 37.5,
        daysToExpiry: 10,
      ),
    ];

    var filtered = items;
    if (category != null && category.isNotEmpty && category != 'Semua' && category != 'All') {
      filtered = filtered.where((l) => l.category.toLowerCase() == category.toLowerCase()).toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      filtered = filtered.where((l) =>
        l.productName.toLowerCase().contains(q) ||
        (l.brand?.toLowerCase().contains(q) ?? false) ||
        l.category.toLowerCase().contains(q)
      ).toList();
    }
    if (radiusKm != null) {
      filtered = filtered.where((l) => (l.distanceKm ?? 0) <= radiusKm).toList();
    }
    if (minDays != null) {
      filtered = filtered.where((l) => (l.daysToExpiry ?? 0) <= minDays).toList();
    }
    if (sort == 'cheapest') {
      filtered.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
    } else if (sort == 'expiring_soon' || sort == 'expiring') {
      filtered.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    } else if (sort == 'highest_match') {
      filtered.sort((a, b) => (b.discountPct ?? 0).compareTo(a.discountPct ?? 0));
    } else if (sort == 'nearest') {
      filtered.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
    }
    return filtered;
  }

  /// Manually cache a list of listings into SQLite.
  Future<void> cacheListings(List<CachedListingModel> listings) async {
    await _localDb.upsertListings(listings);
  }

  // ===========================================================================
  // Draft Listings & Offline Sync Queue
  // ===========================================================================

  /// Create a draft listing and save it into the local SQLite `draft_listings` queue.
  /// Status is initially 'pending'.
  Future<DraftListingModel> saveDraft(DraftListingModel draft) async {
    if (draft.id == null) {
      final generatedId = await _localDb.insertDraft(draft);
      return draft.copyWith(id: generatedId);
    } else {
      await _localDb.updateDraft(draft);
      return draft;
    }
  }

  /// Retrieve all draft listings.
  Future<List<DraftListingModel>> getAllDrafts() async {
    return await _localDb.getAllDrafts();
  }

  /// Retrieve pending draft listings waiting for sync.
  Future<List<DraftListingModel>> getPendingDrafts() async {
    return await _localDb.getPendingDrafts();
  }

  /// Delete a draft from the local database.
  Future<bool> deleteDraft(int id) async {
    final deleted = await _localDb.deleteDraft(id);
    return deleted > 0;
  }

  /// Delete all successfully synced drafts to keep local storage clean.
  Future<int> clearSyncedDrafts() async {
    return await _localDb.clearSyncedDrafts();
  }

  /// Process the offline draft synchronization queue.
  /// Iterates through all `pending` drafts and attempts upload via [client] (or configured [_remoteClient]).
  /// Updates each draft to `synced` (with server_listing_id) or `failed` (with sync_error).
  Future<DraftSyncResult> syncPendingDrafts({RemoteListingClient? client}) async {
    final syncClient = client ?? remoteClient;
    if (syncClient == null) {
      throw StateError('Cannot sync drafts: No RemoteListingClient provided or configured.');
    }

    final pendingDrafts = await _localDb.getPendingDrafts();
    if (pendingDrafts.isEmpty) {
      return const DraftSyncResult(
        totalCount: 0,
        syncedCount: 0,
        failedCount: 0,
        errors: [],
      );
    }

    int syncedCount = 0;
    int failedCount = 0;
    final errors = <String>[];

    for (final draft in pendingDrafts) {
      if (draft.id == null) continue;

      try {
        final serverListingId = await syncClient.uploadDraftListing(draft);
        await _localDb.updateDraftSyncStatus(
          draft.id!,
          DatabaseConstants.syncStatusSynced,
          serverListingId: serverListingId,
        );
        syncedCount++;
      } catch (e) {
        final errorMsg = e.toString();
        await _localDb.updateDraftSyncStatus(
          draft.id!,
          DatabaseConstants.syncStatusFailed,
          syncError: errorMsg,
        );
        failedCount++;
        errors.add('Draft #${draft.id} (${draft.productName}): $errorMsg');
      }
    }

    return DraftSyncResult(
      totalCount: pendingDrafts.length,
      syncedCount: syncedCount,
      failedCount: failedCount,
      errors: errors,
    );
  }

  /// Retry syncing a single failed or pending draft.
  Future<bool> retryDraftSync(int draftId, {RemoteListingClient? client}) async {
    final syncClient = client ?? remoteClient;
    if (syncClient == null) {
      throw StateError('Cannot sync draft: No RemoteListingClient provided or configured.');
    }

    final draft = await _localDb.getDraftById(draftId);
    if (draft == null) return false;

    try {
      final serverListingId = await syncClient.uploadDraftListing(draft);
      await _localDb.updateDraftSyncStatus(
        draftId,
        DatabaseConstants.syncStatusSynced,
        serverListingId: serverListingId,
      );
      return true;
    } catch (e) {
      await _localDb.updateDraftSyncStatus(
        draftId,
        DatabaseConstants.syncStatusFailed,
        syncError: e.toString(),
      );
      return false;
    }
  }
}
