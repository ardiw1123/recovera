import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:recovera/data/data.dart';

// Mock remote client to test online/offline repository scenarios
class MockRemoteListingClient implements RemoteListingClient {
  bool shouldThrow = false;
  int nextServerId = 100;
  List<CachedListingModel> remoteListings = [];

  @override
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
  }) async {
    if (shouldThrow) {
      throw Exception('Network unreachable (Offline)');
    }
    return remoteListings;
  }

  @override
  Future<CachedListingModel?> fetchListingDetail(int id) async {
    if (shouldThrow) {
      throw Exception('Network unreachable (Offline)');
    }
    try {
      return remoteListings.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> uploadDraftListing(DraftListingModel draft) async {
    if (shouldThrow) {
      throw Exception('Server 500: Failed to upload draft');
    }
    return nextServerId++;
  }
}

void main() {
  // Initialize sqflite ffi for desktop/VM test environment
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late AppDatabase appDatabase;
  late LocalDatabaseService localDbService;
  late ListingRepository listingRepo;
  late OrderRepository orderRepo;
  late GameRepository gameRepo;
  late AppPrefsRepository prefsRepo;
  late MockRemoteListingClient mockRemoteClient;

  setUp(() async {
    // Open a fresh in-memory database for each test
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseConstants.databaseVersion,
        onCreate: AppDatabase.createTables,
      ),
    );

    appDatabase = AppDatabase.instance;
    appDatabase.setTestDatabase(db);

    localDbService = LocalDatabaseService(appDatabase: appDatabase);
    mockRemoteClient = MockRemoteListingClient();

    listingRepo = ListingRepository(
      localDb: localDbService,
      remoteClient: mockRemoteClient,
    );
    orderRepo = OrderRepository(localDb: localDbService);
    gameRepo = GameRepository(localDb: localDbService);
    prefsRepo = AppPrefsRepository(localDb: localDbService);
  });

  tearDown(() async {
    await db.close();
    await appDatabase.reset();
  });

  group('Database Schema & Table Creation', () {
    test('All 5 tables are created successfully in SQLite', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames, contains(DatabaseConstants.tableCachedListings));
      expect(tableNames, contains(DatabaseConstants.tableDraftListings));
      expect(tableNames, contains(DatabaseConstants.tableCachedOrders));
      expect(tableNames, contains(DatabaseConstants.tableGameScores));
      expect(tableNames, contains(DatabaseConstants.tableAppPrefs));
    });
  });

  group('Table 1: cached_listings & LocalDatabaseService', () {
    test('upsert, filter, search and sort cached listings offline', () async {
      final listing1 = CachedListingModel(
        id: 1,
        productId: 10,
        sellerId: 5,
        batchNumber: 'BATCH-001',
        qty: 50,
        normalPrice: 100000,
        startPrice: 75000,
        minPrice: 50000,
        currentPrice: 70000,
        expiryDate: '2026-11-01',
        auctionStartAt: '2026-10-10T08:00:00Z',
        auctionEndAt: '2026-10-25T08:00:00Z',
        createdAt: '2026-10-10T08:00:00Z',
        productName: 'Fresh Pasteurized Milk 1L',
        brand: 'GreenFields',
        category: 'Dairy',
        distanceKm: 4.2,
        cachedAt: DateTime.now().toIso8601String(),
      );

      final listing2 = CachedListingModel(
        id: 2,
        productId: 11,
        sellerId: 6,
        batchNumber: 'BATCH-002',
        qty: 20,
        normalPrice: 50000,
        startPrice: 35000,
        minPrice: 20000,
        currentPrice: 30000,
        expiryDate: '2026-10-20',
        auctionStartAt: '2026-10-10T08:00:00Z',
        auctionEndAt: '2026-10-20T08:00:00Z',
        createdAt: '2026-10-10T09:00:00Z',
        productName: 'Wheat Flour 1kg',
        brand: 'Bogasari',
        category: 'Flour & Grain',
        distanceKm: 8.5,
        cachedAt: DateTime.now().toIso8601String(),
      );

      await localDbService.upsertListings([listing1, listing2]);

      // All listings
      final all = await localDbService.getListings();
      expect(all.length, 2);

      // Search by brand / name
      final searchResult = await localDbService.getListings(search: 'GreenFields');
      expect(searchResult.length, 1);
      expect(searchResult.first.productName, 'Fresh Pasteurized Milk 1L');

      // Filter by category
      final categoryResult = await localDbService.getListings(category: 'Flour & Grain');
      expect(categoryResult.length, 1);
      expect(categoryResult.first.batchNumber, 'BATCH-002');

      // Filter by max price
      final priceResult = await localDbService.getListings(maxPrice: 50000);
      expect(priceResult.length, 1);
      expect(priceResult.first.id, 2);

      // Sort by cheapest
      final sortedCheapest = await localDbService.getListings(sort: 'cheapest');
      expect(sortedCheapest.first.id, 2);

      // Sort by nearest
      final sortedNearest = await localDbService.getListings(sort: 'nearest');
      expect(sortedNearest.first.id, 1);
    });
  });

  group('Table 2: draft_listings & Offline Sync Queue', () {
    test('insert draft, query pending, update status to synced', () async {
      final draft = DraftListingModel.create(
        productName: 'Organic Cheddar Cheese',
        brand: 'Kraft',
        category: 'Dairy',
        batchNumber: 'LOT-992',
        qty: 15,
        normalPrice: 65000,
        minPrice: 35000,
        expiryDate: '2026-11-15',
        localImagePath: '/data/user/0/recovera/cache/invoice_ocr.jpg',
      );

      final draftId = await localDbService.insertDraft(draft);
      expect(draftId, greaterThan(0));

      final pending = await localDbService.getPendingDrafts();
      expect(pending.length, 1);
      expect(pending.first.productName, 'Organic Cheddar Cheese');
      expect(pending.first.isPending, isTrue);

      // Mark synced
      await localDbService.updateDraftSyncStatus(
        draftId,
        DatabaseConstants.syncStatusSynced,
        serverListingId: 888,
      );

      final updated = await localDbService.getDraftById(draftId);
      expect(updated?.syncStatus, DatabaseConstants.syncStatusSynced);
      expect(updated?.serverListingId, 888);
      expect(updated?.isSynced, isTrue);

      final pendingAfterSync = await localDbService.getPendingDrafts();
      expect(pendingAfterSync.isEmpty, isTrue);

      // Clear synced drafts
      final cleared = await localDbService.clearSyncedDrafts();
      expect(cleared, 1);

      final allAfterClear = await localDbService.getAllDrafts();
      expect(allAfterClear.isEmpty, isTrue);
    });

    test('ListingRepository executes offline draft sync queue with retry', () async {
      // 1. Create 2 drafts while offline
      await listingRepo.saveDraft(
        DraftListingModel.create(
          productName: 'Butter Unsalted 200g',
          category: 'Dairy',
          batchNumber: 'BT-01',
          qty: 10,
          normalPrice: 40000,
          minPrice: 20000,
          expiryDate: '2026-11-30',
        ),
      );

      await listingRepo.saveDraft(
        DraftListingModel.create(
          productName: 'Full Cream Milk 1L',
          category: 'Dairy',
          batchNumber: 'ML-02',
          qty: 25,
          normalPrice: 25000,
          minPrice: 15000,
          expiryDate: '2026-11-10',
        ),
      );

      var pending = await listingRepo.getPendingDrafts();
      expect(pending.length, 2);

      // 2. Simulate sync failure when server throws
      mockRemoteClient.shouldThrow = true;
      final failedResult = await listingRepo.syncPendingDrafts();
      expect(failedResult.totalCount, 2);
      expect(failedResult.syncedCount, 0);
      expect(failedResult.failedCount, 2);

      final failedDrafts = await listingRepo.getAllDrafts();
      expect(failedDrafts.every((d) => d.isFailed), isTrue);
      expect(failedDrafts.first.syncError, contains('Server 500'));

      // 3. Connectivity restored: retry sync
      mockRemoteClient.shouldThrow = false;
      // Mark drafts back to pending or retry draft directly
      final retrySuccess = await listingRepo.retryDraftSync(failedDrafts.first.id!);
      expect(retrySuccess, isTrue);

      final retriedDraft = await localDbService.getDraftById(failedDrafts.first.id!);
      expect(retriedDraft?.isSynced, isTrue);
      expect(retriedDraft?.serverListingId, isNotNull);
    });
  });

  group('Table 3: cached_orders & Compass Navigation Coordinates', () {
    test('cache orders with seller warehouse lat/lng for offline compass navigation', () async {
      final order = CachedOrderModel(
        id: 501,
        listingId: 101,
        buyerId: 77,
        qty: 5,
        finalUnitPrice: 45000,
        totalPrice: 225000,
        status: 'paid',
        createdAt: '2026-10-11T12:00:00Z',
        productName: 'Instant Yeast 500g',
        category: 'Baking',
        batchNumber: 'YST-2026',
        warehouseLat: -6.2088,
        warehouseLng: 106.8456,
        warehouseAddress: 'Jl. Industri Pangan No. 12, Jakarta',
        cachedAt: DateTime.now().toIso8601String(),
      );

      await orderRepo.cacheOrder(order);

      final cachedOrders = await orderRepo.getOrders(buyerId: 77);
      expect(cachedOrders.length, 1);
      final retrieved = cachedOrders.first;
      expect(retrieved.productName, 'Instant Yeast 500g');
      expect(retrieved.warehouseLat, -6.2088);
      expect(retrieved.warehouseLng, 106.8456);
      expect(retrieved.warehouseAddress, contains('Jl. Industri'));
    });
  });

  group('Table 4: game_scores & Food Saver Challenge Mini-game', () {
    test('record game scores, assign badges, and calculate leaderboard', () async {
      // Rookie game
      await gameRepo.recordGameScore(score: 40, itemsSaved: 4);

      // Hero game
      await gameRepo.recordGameScore(score: 120, itemsSaved: 12);

      // Champion game
      await gameRepo.recordGameScore(score: 250, itemsSaved: 22);

      final leaderboard = await gameRepo.getLeaderboard(limit: 5);
      expect(leaderboard.length, 3);
      expect(leaderboard.first.score, 250);
      expect(leaderboard.first.badge, 'Zero Waste Champion');

      expect(leaderboard[1].score, 120);
      expect(leaderboard[1].badge, 'Food Saver Hero');

      expect(leaderboard[2].badge, isNull);

      final totalItems = await gameRepo.getTotalItemsSaved();
      expect(totalItems, 4 + 12 + 22);
    });
  });

  group('Table 5: app_prefs (Biometric, Timezone, Currency Rates)', () {
    test('persist biometric toggle, timezone preference, and currency exchange rates', () async {
      // 1. Biometric toggle (default false)
      expect(await prefsRepo.isBiometricEnabled(), isFalse);
      await prefsRepo.setBiometricEnabled(true);
      expect(await prefsRepo.isBiometricEnabled(), isTrue);

      // 2. Timezone preference (default WIB)
      expect(await prefsRepo.getSelectedTimezone(), 'WIB');
      await prefsRepo.setSelectedTimezone('London');
      expect(await prefsRepo.getSelectedTimezone(), 'London');

      // 3. Currency exchange rates JSON persistence
      final initialRates = await prefsRepo.getLastCurrencyRates();
      expect(initialRates.isEmpty, isTrue);

      final ratesToSave = {
        'USD': 0.000063,
        'EUR': 0.000058,
        'GBP': 0.000050,
      };
      await prefsRepo.setLastCurrencyRates(ratesToSave);

      final retrievedRates = await prefsRepo.getLastCurrencyRates();
      expect(retrievedRates['USD'], closeTo(0.000063, 0.0000001));
      expect(retrievedRates['EUR'], closeTo(0.000058, 0.0000001));
      expect(retrievedRates['GBP'], closeTo(0.000050, 0.0000001));
    });
  });

  group('ListingRepository: Offline-First & Cache Indicator Flag', () {
    test('returns cached listings with isFromCache: true when offline', () async {
      // Seed SQLite cache
      final item = CachedListingModel(
        id: 99,
        productId: 1,
        sellerId: 1,
        batchNumber: 'B-99',
        qty: 10,
        normalPrice: 50000,
        startPrice: 40000,
        minPrice: 30000,
        currentPrice: 35000,
        expiryDate: '2026-10-30',
        auctionStartAt: '2026-10-10T00:00:00Z',
        auctionEndAt: '2026-10-20T00:00:00Z',
        createdAt: '2026-10-10T00:00:00Z',
        productName: 'Cached Butter',
        category: 'Dairy',
        cachedAt: DateTime.now().toIso8601String(),
      );
      await localDbService.upsertListing(item);

      // Network request fails (offline)
      mockRemoteClient.shouldThrow = true;

      final result = await listingRepo.getListings(forceRefresh: true);
      expect(result.isFromCache, isTrue);
      expect(result.listings.length, 1);
      expect(result.listings.first.productName, 'Cached Butter');
      expect(result.errorMessage, isNotNull);
    });

    test('returns fresh listings with isFromCache: false when online and refreshes cache', () async {
      mockRemoteClient.shouldThrow = false;
      mockRemoteClient.remoteListings = [
        CachedListingModel(
          id: 100,
          productId: 2,
          sellerId: 2,
          batchNumber: 'B-100',
          qty: 8,
          normalPrice: 80000,
          startPrice: 60000,
          minPrice: 40000,
          currentPrice: 55000,
          expiryDate: '2026-11-05',
          auctionStartAt: '2026-10-11T00:00:00Z',
          auctionEndAt: '2026-10-22T00:00:00Z',
          createdAt: '2026-10-11T00:00:00Z',
          productName: 'Fresh Remote Butter',
          category: 'Dairy',
          cachedAt: DateTime.now().toIso8601String(),
        ),
      ];

      final result = await listingRepo.getListings(forceRefresh: true);
      expect(result.isFromCache, isFalse);
      expect(result.listings.length, 1);
      expect(result.listings.first.productName, 'Fresh Remote Butter');

      // Verify that SQLite was updated with the fresh remote listing
      final inDb = await localDbService.getListingById(100);
      expect(inDb, isNotNull);
      expect(inDb?.productName, 'Fresh Remote Butter');
    });
  });
}
