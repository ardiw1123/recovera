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
        await _localDb.upsertListings(remoteItems);

        return ListingResult(
          listings: remoteItems,
          isFromCache: false,
        );
      } catch (e) {
        // Fallback to SQLite cache on network failure
        final cachedItems = await _localDb.getListings(
          search: search,
          category: category,
          maxPrice: maxPrice,
          minDays: minDays,
          sort: sort,
          radiusKm: radiusKm,
        );
        return ListingResult(
          listings: cachedItems,
          isFromCache: true,
          errorMessage: e.toString(),
        );
      }
    }

    // Default: query local SQLite cache first (offline-first paradigm)
    final cached = await _localDb.getListings(
      search: search,
      category: category,
      maxPrice: maxPrice,
      minDays: minDays,
      sort: sort,
      radiusKm: radiusKm,
    );

    // If cache is empty and remote client is available, try fetching once
    if (cached.isEmpty && client != null) {
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
        await _localDb.upsertListings(remoteItems);
        return ListingResult(listings: remoteItems, isFromCache: false);
      } catch (_) {
        return ListingResult(listings: const [], isFromCache: true);
      }
    }

    return ListingResult(listings: cached, isFromCache: true);
  }

  /// Get a single listing by ID, checking remote detail if [forceRefresh] is true, else checking local cache first.
  Future<CachedListingModel?> getListingById(int id, {bool forceRefresh = false}) async {
    final client = remoteClient;
    if (client != null && forceRefresh) {
      try {
        final remoteDetail = await client.fetchListingDetail(id);
        if (remoteDetail != null) {
          await _localDb.upsertListings([remoteDetail]);
          return remoteDetail;
        }
      } catch (_) {}
    }

    final cached = await _localDb.getListingById(id);
    if (cached != null) return cached;

    if (client != null) {
      try {
        final remoteDetail = await client.fetchListingDetail(id);
        if (remoteDetail != null) {
          await _localDb.upsertListings([remoteDetail]);
          return remoteDetail;
        }
      } catch (_) {}
    }
    return null;
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
