import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/storage/token_storage.dart';
import 'package:recovera/data/models/cached_listing_model.dart';
import 'package:recovera/data/models/cached_order_model.dart';
import 'package:recovera/data/repositories/auth_repository.dart';
import 'package:recovera/data/repositories/listing_repository.dart';
import 'package:recovera/data/repositories/order_repository.dart';
import 'package:recovera/data/services/auth_api_service.dart';
import 'package:recovera/features/home/models/product_model.dart';
import 'package:recovera/features/home/screens/home_screen.dart';
import 'package:recovera/features/home/screens/product_detail_screen.dart';

class TestMockAdapter implements HttpClientAdapter {
  TestMockAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}

  static ResponseBody json(dynamic data, {int statusCode = 200}) {
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(data)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Listing _createTestListing({
  int id = 1,
  String productName = 'Susu UHT Fresh 1L',
  String companyName = 'PT Sumber Dairy Sejahtera',
  String city = 'Jakarta Selatan',
  double normalPrice = 25000,
  double startPrice = 15000,
  int qty = 120,
  double? distanceKm = 3.2,
  double? matchScore = 0.94,
  double? discountPct = 40.0,
  int? daysToExpiry = 4,
  FoodCategory category = FoodCategory.dairy,
  String storageType = 'chilled',
}) {
  final now = DateTime.now();
  return Listing(
    id: id,
    productId: 101,
    sellerId: 10,
    batchNumber: 'BATCH-2026-X1',
    qty: qty,
    normalPrice: normalPrice,
    startPrice: startPrice,
    minPrice: 10000,
    dropIntervalMinutes: 60,
    dropPercentage: 5,
    expiryDate: now.add(const Duration(days: 4)),
    auctionStartAt: now.subtract(const Duration(hours: 12)),
    auctionEndAt: now.add(const Duration(days: 3)),
    status: 'active',
    createdAt: now.subtract(const Duration(days: 1)),
    productName: productName,
    brand: 'GreenField Fresh',
    category: category,
    storageType: storageType,
    defaultUnit: 'karton',
    companyName: companyName,
    warehouseLat: -6.2200,
    warehouseLng: 106.8300,
    city: city,
    distanceKm: distanceKm,
    matchScore: matchScore,
    discountPct: discountPct,
    daysToExpiry: daysToExpiry,
  );
}

CachedListingModel _createTestCachedModel({
  int id = 1,
  String productName = 'Susu UHT Fresh 1L',
  String companyName = 'PT Sumber Dairy Sejahtera',
  String city = 'Jakarta Selatan',
  double normalPrice = 25000,
  double startPrice = 15000,
  int qty = 120,
  double? distanceKm = 3.2,
  double? matchScore = 0.94,
  double? discountPct = 40.0,
  int? daysToExpiry = 4,
  String category = 'Dairy',
  String storageType = 'chilled',
}) {
  return CachedListingModel(
    id: id,
    productId: 101,
    sellerId: 10,
    batchNumber: 'BATCH-2026-X1',
    qty: qty,
    normalPrice: normalPrice,
    startPrice: startPrice,
    minPrice: 10000,
    currentPrice: startPrice,
    dropIntervalMinutes: 60,
    dropPercentage: 5,
    expiryDate: DateTime.now().add(const Duration(days: 4)).toIso8601String(),
    auctionStartAt: DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
    auctionEndAt: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
    status: 'active',
    createdAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    productName: productName,
    brand: 'GreenField Fresh',
    category: category,
    storageType: storageType,
    defaultUnit: 'karton',
    sellerCompany: companyName,
    warehouseLat: -6.2200,
    warehouseLng: 106.8300,
    warehouseCity: city,
    cachedAt: DateTime.now().toIso8601String(),
    distanceKm: distanceKm,
    matchScore: matchScore,
    discountPct: discountPct,
    daysToExpiry: daysToExpiry,
  );
}

class TestListingRepository extends ListingRepository {
  TestListingRepository({
    required this.resultListings,
    this.isCache = false,
  });

  final List<CachedListingModel> resultListings;
  final bool isCache;

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
    var items = List<CachedListingModel>.from(resultListings);
    if (category != null && category.isNotEmpty) {
      items = items.where((i) => i.category.toLowerCase() == category.toLowerCase()).toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      items = items.where((i) =>
        i.productName.toLowerCase().contains(q) ||
        (i.sellerCompany?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    return ListingResult(listings: items, isFromCache: isCache);
  }

  @override
  Future<CachedListingModel?> getListingById(int id, {bool forceRefresh = false}) async {
    try {
      return resultListings.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}

class TestOrderRepository extends OrderRepository {
  TestOrderRepository({this.onBuyCallback});

  final void Function(int listingId, int qty)? onBuyCallback;

  @override
  Future<CachedOrderModel> buyListing(int listingId, {int qty = 1, bool biometricVerified = true}) async {
    if (onBuyCallback != null) {
      onBuyCallback!(listingId, qty);
    }
    return CachedOrderModel(
      id: 991,
      listingId: listingId,
      buyerId: 42,
      qty: qty,
      finalUnitPrice: 15000,
      totalPrice: 15000.0 * qty,
      status: 'confirmed',
      createdAt: DateTime.now().toIso8601String(),
      productName: 'Test Product',
      category: 'Dairy',
      batchNumber: 'BATCH-2026-X1',
      cachedAt: DateTime.now().toIso8601String(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Buyer Models & Proximity Metrics Unit Tests', () {
    test('Listing model computes effective proximity match metrics', () {
      final listing = _createTestListing(
        distanceKm: 2.45,
        matchScore: 0.965,
        discountPct: 45.0,
        daysToExpiry: 3,
      );

      expect(listing.matchScorePercentage, '97% Match');
      expect(listing.effectiveMatchScore, 0.965);
      expect(listing.distanceText, '2.5 km');
      expect(listing.effectiveDiscountPercent, 45);
      expect(listing.effectiveDaysToExpiry, 3);
      expect(listing.isLiveDutch, isTrue);
    });

    test('Listing model computes discount from prices if discountPct is null', () {
      final listing = _createTestListing(
        normalPrice: 50000,
        startPrice: 20000,
        discountPct: null,
      );

      expect(listing.discountPercent, 60);
      expect(listing.effectiveDiscountPercent, 60);
    });

    test('Listing model handles missing distanceKm gracefully by showing city', () {
      final listing = _createTestListing(
        distanceKm: null,
        city: 'Surabaya',
      );

      expect(listing.distanceText, 'Surabaya');
    });

    test('CachedListingModel converts to and from Listing model accurately', () {
      final cached = _createTestCachedModel(
        id: 42,
        productName: 'Tepung Terigu Segitiga Biru',
        matchScore: 0.91,
        discountPct: 35.0,
        distanceKm: 1.8,
        daysToExpiry: 5,
      );

      final listing = Listing.fromCachedModel(cached);
      expect(listing.id, 42);
      expect(listing.productName, 'Tepung Terigu Segitiga Biru');
      expect(listing.matchScore, 0.91);
      expect(listing.discountPct, 35.0);
      expect(listing.distanceKm, 1.8);
      expect(listing.daysToExpiry, 5);
      expect(listing.matchScorePercentage, '91% Match');
      expect(listing.distanceText, '1.8 km');
    });
  });

  group('HomeScreen Widget Tests', () {
    late InMemoryTokenStorage storage;
    late AuthRepository authRepo;

    setUp(() async {
      storage = InMemoryTokenStorage();
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'test-buyer-token',
          refreshToken: 'test-buyer-refresh',
          userId: 42,
          role: 'buyer',
        ),
      );

      final adapter = TestMockAdapter((options) async {
        return TestMockAdapter.json({'success': true, 'data': {}});
      });
      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
      await authRepo.init();
      AuthRepository.instance = authRepo;
    });

    testWidgets('Renders Buyer Greeting, Branding, Location, and Proximity badge', (tester) async {
      final listings = [
        _createTestCachedModel(id: 1, productName: 'Susu UHT Fresh 1L'),
      ];
      final mockListingRepo = TestListingRepository(resultListings: listings);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: mockListingRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Header branding & greeting
      expect(find.text('RECOVERA B2B'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.byKey(const Key('buyer_greeting_title')), findsOneWidget);

      // Location bar & proximity radius
      expect(find.byKey(const Key('buyer_location_text')), findsOneWidget);
      expect(find.byKey(const Key('proximity_radius_badge')), findsOneWidget);
      expect(find.text('Radius < 15 km'), findsOneWidget);

      // Search & recommendation header
      expect(find.byKey(const Key('home_search_field')), findsOneWidget);
      expect(find.byKey(const Key('section_recommendations_title')), findsOneWidget);
      expect(find.text('Rekomendasi Terdekat'), findsOneWidget);

      // Recommendation card
      expect(find.byKey(const Key('product_card_1')), findsOneWidget);
      expect(find.text('Susu UHT Fresh 1L'), findsOneWidget);
      expect(find.byKey(const Key('match_score_badge_1')), findsOneWidget);
      expect(find.text('94% Match'), findsOneWidget);
    });

    testWidgets('Search query filters recommendation cards in real-time', (tester) async {
      final listings = [
        _createTestCachedModel(id: 1, productName: 'Susu UHT Fresh 1L'),
        _createTestCachedModel(id: 2, productName: 'Keju Mozzarella Melt 500g'),
      ];
      final mockListingRepo = TestListingRepository(resultListings: listings);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: mockListingRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Susu UHT Fresh 1L'), findsOneWidget);
      expect(find.text('Keju Mozzarella Melt 500g'), findsOneWidget);

      // Filter for Keju
      await tester.enterText(find.byKey(const Key('home_search_field')), 'Keju');
      await tester.pump();

      expect(find.text('Keju Mozzarella Melt 500g'), findsOneWidget);
      expect(find.text('Susu UHT Fresh 1L'), findsNothing);

      // Query with no match shows empty state
      await tester.enterText(find.byKey(const Key('home_search_field')), 'BerasRojoleleTidakAda');
      await tester.pump();

      expect(find.byKey(const Key('home_empty_state')), findsOneWidget);
      expect(find.text('Tidak ada stok lelang di dekat lokasi Anda'), findsOneWidget);
    });

    testWidgets('Category chips filter listings properly', (tester) async {
      final listings = [
        _createTestCachedModel(id: 1, productName: 'Susu UHT Fresh 1L', category: 'Dairy'),
        _createTestCachedModel(id: 2, productName: 'Minyak Goreng Sawit 2L', category: 'Oil'),
      ];
      final mockListingRepo = TestListingRepository(resultListings: listings);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: mockListingRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Susu UHT Fresh 1L'), findsOneWidget);
      expect(find.text('Minyak Goreng Sawit 2L'), findsOneWidget);

      // Tap Oil category chip
      await tester.tap(find.text('Oil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Minyak Goreng Sawit 2L'), findsOneWidget);
      expect(find.text('Susu UHT Fresh 1L'), findsNothing);
    });

    testWidgets('Offline cache displays visual banner indicator', (tester) async {
      final listings = [
        _createTestCachedModel(id: 1, productName: 'Susu UHT Fresh 1L'),
      ];
      // Repository returns with isCache = true
      final mockListingRepo = TestListingRepository(resultListings: listings, isCache: true);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: mockListingRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('offline_indicator_banner')), findsOneWidget);
      expect(find.text('Mode Offline — Menampilkan data cache SQLite'), findsOneWidget);
      expect(find.byKey(const Key('product_card_1')), findsOneWidget);
    });

    testWidgets('Seller accounts are blocked from accessing buyer HomeScreen', (tester) async {
      // Configure seller role
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'test-seller-token',
          refreshToken: 'test-seller-refresh',
          userId: 99,
          role: 'seller',
        ),
      );
      await authRepo.init();

      final mockListingRepo = TestListingRepository(resultListings: []);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: mockListingRepo),
        ),
      );
      await tester.pump();

      // Verified role barrier
      expect(find.byKey(const Key('seller_access_restricted_title')), findsOneWidget);
      expect(find.text('Akses Terbatas: Khusus Pembeli'), findsOneWidget);
      expect(find.text('Akun penjual tidak diizinkan mengakses fitur discovery katalog pembeli.'), findsOneWidget);
      expect(find.byKey(const Key('home_search_field')), findsNothing);
    });
  });

  group('ProductDetailScreen & Purchase Flow Widget Tests', () {
    late InMemoryTokenStorage storage;
    late AuthRepository authRepo;

    setUp(() async {
      storage = InMemoryTokenStorage();
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'test-buyer-token',
          refreshToken: 'test-buyer-refresh',
          userId: 42,
          role: 'buyer',
        ),
      );

      final adapter = TestMockAdapter((options) async {
        return TestMockAdapter.json({'success': true, 'data': {}});
      });
      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
      await authRepo.init();
      AuthRepository.instance = authRepo;
    });

    testWidgets('Renders full specifications, shelf life warning, seller card, and badges', (tester) async {
      final listing = _createTestListing(
        id: 10,
        productName: 'Yogurt Greek Natural 1kg',
        companyName: 'PT Bio Pangan Nusantara',
        matchScore: 0.98,
        discountPct: 50.0,
        daysToExpiry: 2, // Urgent shelf life
        storageType: 'chilled',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailScreen(listing: listing),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Badges
      expect(find.byKey(const Key('detail_match_score_badge')), findsOneWidget);
      expect(find.text('98% Match'), findsOneWidget);
      expect(find.byKey(const Key('detail_discount_badge')), findsOneWidget);
      expect(find.text('-50%'), findsOneWidget);

      // Shelf life warning
      expect(find.byKey(const Key('detail_shelf_life_warning')), findsOneWidget);
      expect(find.text('Sisa 2 Hari Sebelum Kedaluwarsa'), findsOneWidget);

      // Verified seller
      expect(find.text('Distributor Terverifikasi'), findsOneWidget);
      expect(find.text('PT Bio Pangan Nusantara'), findsOneWidget);

      // Specs
      expect(find.text('Spesifikasi Produk Pangan'), findsOneWidget);
      expect(find.text('BATCH-2026-X1'), findsOneWidget);

      // Sticky buy bar
      expect(find.byKey(const Key('btn_buy_now')), findsOneWidget);
      expect(find.text('Beli Sekarang'), findsOneWidget);
    });

    testWidgets('Quantity counter increments and decrements correctly', (tester) async {
      final listing = _createTestListing(id: 10, qty: 50);

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailScreen(listing: listing),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(find.byKey(const Key('text_qty_value')));
      expect(find.byKey(const Key('text_qty_value')), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      // Increment
      await tester.ensureVisible(find.byKey(const Key('btn_qty_increase')));
      await tester.tap(find.byKey(const Key('btn_qty_increase')));
      await tester.pump();
      expect(find.text('2'), findsWidgets);

      // Increment again
      await tester.tap(find.byKey(const Key('btn_qty_increase')));
      await tester.pump();
      expect(find.text('3'), findsWidgets);

      // Decrement
      await tester.ensureVisible(find.byKey(const Key('btn_qty_decrease')));
      await tester.tap(find.byKey(const Key('btn_qty_decrease')));
      await tester.pump();
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('Beli Sekarang triggers confirmation sheet and executes purchase workflow', (tester) async {
      final listing = _createTestListing(id: 10, qty: 50);
      int? purchasedListingId;
      int? purchasedQty;

      final testOrderRepo = TestOrderRepository(
        onBuyCallback: (id, qty) {
          purchasedListingId = id;
          purchasedQty = qty;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailScreen(
            listing: listing,
            orderRepository: testOrderRepo,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Increase qty to 3
      await tester.ensureVisible(find.byKey(const Key('btn_qty_increase')));
      await tester.tap(find.byKey(const Key('btn_qty_increase')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_qty_increase')));
      await tester.pump();

      // Tap 'Beli Sekarang'
      await tester.tap(find.byKey(const Key('btn_buy_now')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation sheet visible
      expect(find.text('Konfirmasi Pembelian'), findsOneWidget);
      expect(find.byKey(const Key('btn_confirm_purchase_sheet')), findsOneWidget);

      // Confirm purchase
      await tester.tap(find.byKey(const Key('btn_confirm_purchase_sheet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify callback triggered
      expect(purchasedListingId, 10);
      expect(purchasedQty, 3);

      // Verify purchase success dialog
      expect(find.text('Pembelian Berhasil!'), findsOneWidget);
      expect(find.byKey(const Key('btn_order_success_confirm')), findsOneWidget);
    });

    testWidgets('Tapping ProductCard in HomeScreen navigates to ProductDetailScreen', (tester) async {
      final listings = [
        _createTestCachedModel(id: 5, productName: 'Susu Pasteurisasi Cokelat'),
      ];
      final mockListingRepo = TestListingRepository(resultListings: listings);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: mockListingRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('product_card_5')), findsOneWidget);

      // Tap on the card
      await tester.tap(find.byKey(const Key('product_card_5')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should be on ProductDetailScreen
      expect(find.text('Detail Produk'), findsWidgets);
      expect(find.byKey(const Key('btn_buy_now')), findsOneWidget);
      expect(find.text('Susu Pasteurisasi Cokelat'), findsWidgets);
    });

    testWidgets('Seller accounts are blocked from ProductDetailScreen', (tester) async {
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'test-seller-token',
          refreshToken: 'test-seller-refresh',
          userId: 99,
          role: 'seller',
        ),
      );
      await authRepo.init();

      final listing = _createTestListing(id: 10);

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailScreen(listing: listing),
        ),
      );
      await tester.pump();

      expect(find.text('Akses Dibatasi'), findsOneWidget);
      expect(find.text('Akun penjual tidak memiliki izin untuk mengakses halaman detail pembelian produk.'), findsOneWidget);
      expect(find.byKey(const Key('btn_buy_now')), findsNothing);
    });
  });
}
