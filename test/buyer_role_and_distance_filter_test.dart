import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/storage/token_storage.dart';
import 'package:recovera/data/models/cached_listing_model.dart';
import 'package:recovera/data/repositories/auth_repository.dart';
import 'package:recovera/data/repositories/listing_repository.dart';
import 'package:recovera/data/services/auth_api_service.dart';
import 'package:recovera/features/home/screens/home_screen.dart';
import 'package:recovera/features/home/widgets/filter_bottom_sheet.dart';
import 'package:recovera/features/shell/main_shell.dart';
import 'package:recovera/features/stok/screens/stok_screen.dart';

class _TrackingListingRepository extends ListingRepository {
  _TrackingListingRepository({required this.items}) : super();

  final List<CachedListingModel> items;
  double? lastRequestedRadiusKm;
  int getListingsCallCount = 0;

  @override
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
    getListingsCallCount++;
    lastRequestedRadiusKm = radiusKm;

    var result = List<CachedListingModel>.from(items);
    if (radiusKm != null && radiusKm > 0) {
      result = result
          .where((i) => i.distanceKm == null || i.distanceKm! <= radiusKm)
          .toList();
    }
    if (category != null && category.isNotEmpty) {
      result = result
          .where((i) => i.category.toLowerCase() == category.toLowerCase())
          .toList();
    }
    return ListingResult(listings: result, isFromCache: false);
  }
}

CachedListingModel _makeListing({
  required int id,
  required String productName,
  required double distanceKm,
  String category = 'Dairy',
}) {
  return CachedListingModel(
    id: id,
    productId: id,
    sellerId: 10,
    batchNumber: 'BATCH-$id',
    qty: 100,
    normalPrice: 50000.0,
    startPrice: 35000.0,
    minPrice: 20000.0,
    currentPrice: 30000.0,
    expiryDate: '2026-12-31T00:00:00Z',
    auctionStartAt: '2026-01-01T00:00:00Z',
    auctionEndAt: '2026-12-31T00:00:00Z',
    createdAt: '2026-01-01T00:00:00Z',
    productName: productName,
    category: category,
    sellerCompany: 'PT Food Distributor',
    warehouseCity: 'Jakarta',
    cachedAt: DateTime.now().toIso8601String(),
    distanceKm: distanceKm,
  );
}

class _MockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode({'success': true, 'data': {}})),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryTokenStorage tokenStorage;
  late AuthRepository authRepo;

  setUp(() async {
    tokenStorage = InMemoryTokenStorage();
    final client = ApiClient(tokenStorage: tokenStorage, adapter: _MockAdapter());
    authRepo = AuthRepository(
      authApiService: AuthApiService(client: client),
      tokenStorage: tokenStorage,
    );
    AuthRepository.instance = authRepo;
  });

  group('Phase 1: Buyer Navigation Role Guarding', () {
    testWidgets('MainShell for Buyer: Stok tab is strictly removed', (tester) async {
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'buyer-token-123',
          refreshToken: 'buyer-refresh',
          userId: 201,
          role: 'buyer',
        ),
      );
      await authRepo.init();

      final mockRepo = _TrackingListingRepository(items: []);

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            listingRepository: mockRepo,
            profilePage: const Center(child: Text('Halaman Profil')),
            feedbackPage: const Center(child: Text('Halaman Saran')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Buyer bottom navigation verification
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Saran'), findsOneWidget);

      // STOK tab must NOT exist in the bottom navigation for buyer
      expect(find.text('Stok'), findsNothing);
      expect(find.byKey(const Key('nav_seller_add_stock')), findsNothing);
      expect(find.text('Tambah'), findsNothing);

      // Tapping 'Profil' must open profilePage, NOT StokScreen or restricted barrier
      await tester.tap(find.text('Profil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Halaman Profil'), findsOneWidget);
      expect(find.text('Akses Terbatas: Khusus Penjual'), findsNothing);

      // Tapping 'Saran' must open feedbackPage
      await tester.tap(find.text('Saran'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Halaman Saran'), findsOneWidget);

      // Tapping 'Home' returns to Home screen
      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('MainShell for Seller: Stok tab and Tambah button are present', (tester) async {
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'seller-token-123',
          refreshToken: 'seller-refresh',
          userId: 101,
          role: 'seller',
        ),
      );
      await authRepo.init();

      await tester.pumpWidget(
        const MaterialApp(
          home: MainShell(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Seller navigation has Beranda, Stok, Tambah, Profil, Saran
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Stok'), findsOneWidget);
      expect(find.byKey(const Key('nav_seller_add_stock')), findsOneWidget);
      expect(find.text('Tambah'), findsOneWidget);
    });

    testWidgets('StokScreen blocks Buyer accounts with access restricted view', (tester) async {
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'buyer-token-123',
          refreshToken: 'buyer-refresh',
          userId: 201,
          role: 'buyer',
        ),
      );
      await authRepo.init();

      await tester.pumpWidget(
        const MaterialApp(
          home: StokScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Buyer should see restriction barrier
      expect(find.byKey(const Key('stok_buyer_access_restricted_title')), findsOneWidget);
      expect(find.text('Akses Terbatas: Khusus Penjual'), findsOneWidget);
      expect(find.text('Fitur manajemen stok lelang hanya dapat diakses oleh akun penjual.'), findsOneWidget);
    });
  });

  group('Phase 2 & Phase 3: Configurable Distance Radius Filter', () {
    testWidgets('HomeScreen displays default 15 km radius in proximity badge', (tester) async {
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'buyer-token',
          refreshToken: 'refresh-token',
          userId: 301,
          role: 'buyer',
        ),
      );
      await authRepo.init();

      final mockRepo = _TrackingListingRepository(items: [
        _makeListing(id: 1, productName: 'Susu Segar 1L', distanceKm: 5.0),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: mockRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('proximity_radius_badge')), findsOneWidget);
      expect(find.text('Radius < 15 km'), findsOneWidget);
      expect(find.byKey(const Key('btn_home_filter')), findsOneWidget);
      expect(find.text('Susu Segar 1L'), findsOneWidget);
    });

    testWidgets('FilterBottomSheet provides distance slider and preset chips beyond 15 km', (tester) async {
      double appliedRadius = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBottomSheet(
              selectedCategories: const {},
              selectedExpiryPreset: 'all',
              selectedSort: 'nearest',
              selectedRadiusKm: 15.0,
              onApply: (cats, expiry, sort, radius) {
                appliedRadius = radius;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(find.byKey(const Key('filter_distance_chip_30')), 300, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();

      expect(find.text('3. RADIUS PENEMUAN GUDANG'), findsOneWidget);
      expect(find.byKey(const Key('filter_radius_badge_text')), findsOneWidget);
      expect(find.text('15 km'), findsOneWidget);
      expect(find.byKey(const Key('filter_distance_slider')), findsOneWidget);
      expect(find.byKey(const Key('filter_distance_chip_20')), findsOneWidget);
      expect(find.byKey(const Key('filter_distance_chip_30')), findsOneWidget);
      expect(find.byKey(const Key('filter_distance_chip_50')), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter_distance_chip_30')));
      await tester.pump();

      expect(find.text('30 km'), findsOneWidget);

      // Tap apply
      await tester.tap(find.byKey(const Key('btn_apply_filter_sheet')));
      await tester.pump();

      expect(appliedRadius, 30.0);
    });

    testWidgets('Custom distance selection retrieves and renders products within expanded radius', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'buyer-token',
          refreshToken: 'refresh-token',
          userId: 301,
          role: 'buyer',
        ),
      );
      await authRepo.init();

      final items = [
        _makeListing(id: 1, productName: 'Produk Dekat (8 km)', distanceKm: 8.0),
        _makeListing(id: 2, productName: 'Produk Menengah (25 km)', distanceKm: 25.0),
        _makeListing(id: 3, productName: 'Produk Jauh (45 km)', distanceKm: 45.0),
      ];

      final mockRepo = _TrackingListingRepository(items: items);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: mockRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Initial default state: 15 km radius
      // Only Produk Dekat (8 km) is within 15 km
      expect(find.text('Produk Dekat (8 km)'), findsOneWidget);
      expect(find.text('Produk Menengah (25 km)'), findsNothing);
      expect(find.text('Produk Jauh (45 km)'), findsNothing);
      expect(find.text('Radius < 15 km'), findsOneWidget);

      // 2. Open FilterBottomSheet via proximity badge
      await tester.tap(find.byKey(const Key('btn_proximity_filter')));
      await tester.pumpAndSettle();

      // 3. Choose 30 km preset chip
      await tester.scrollUntilVisible(find.byKey(const Key('filter_distance_chip_30')), 300, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter_distance_chip_30')));
      await tester.pumpAndSettle();

      // 4. Apply filter
      await tester.tap(find.byKey(const Key('btn_apply_filter_sheet')));
      await tester.pumpAndSettle();

      // Verify repository was queried with radiusKm = 30.0
      expect(mockRepo.lastRequestedRadiusKm, 30.0);

      // Verify UI badge and banner indicator
      expect(find.text('Radius < 30 km'), findsOneWidget);
      expect(find.byKey(const Key('chip_active_radius')), findsOneWidget);
      expect(find.text('Jarak: 30 km'), findsOneWidget);

      // Products check: Produk Dekat (8 km) and Produk Menengah (25 km) are visible
      expect(find.text('Produk Dekat (8 km)'), findsOneWidget);
      expect(find.text('Produk Menengah (25 km)'), findsOneWidget);
      // Produk Jauh (45 km) is still outside 30 km
      expect(find.text('Produk Jauh (45 km)'), findsNothing);

      // 5. Expand distance further to 50 km
      await tester.tap(find.byKey(const Key('btn_home_filter')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.byKey(const Key('filter_distance_chip_50')), 300, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter_distance_chip_50')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_apply_filter_sheet')));
      await tester.pumpAndSettle();

      expect(mockRepo.lastRequestedRadiusKm, 50.0);
      expect(find.text('Radius < 50 km'), findsOneWidget);

      // All 3 products are now visible within 50 km!
      expect(find.text('Produk Dekat (8 km)'), findsOneWidget);
      expect(find.text('Produk Menengah (25 km)'), findsOneWidget);
      expect(find.text('Produk Jauh (45 km)'), findsOneWidget);

      // 6. Reset radius filter via banner clear button
      await tester.tap(find.byKey(const Key('btn_clear_radius_filter')));
      await tester.pumpAndSettle();

      // Radius resets to default 15 km
      expect(find.text('Radius < 15 km'), findsOneWidget);
      expect(find.text('Produk Dekat (8 km)'), findsOneWidget);
      expect(find.text('Produk Menengah (25 km)'), findsNothing);
      expect(find.text('Produk Jauh (45 km)'), findsNothing);
    });
  });
}
