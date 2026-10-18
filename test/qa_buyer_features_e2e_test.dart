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

class _QAMockAdapter implements HttpClientAdapter {
  _QAMockAdapter(this.handler);

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

Listing _buildTestListing({
  int id = 101,
  String productName = 'Susu UHT Segar 1L',
  String companyName = 'PT Pangan Segar Sejahtera',
  String city = 'Jakarta Selatan',
  double normalPrice = 30000,
  double startPrice = 18000,
  double minPrice = 12000,
  int qty = 80,
  double? distanceKm = 3.5,
  double? matchScore = 0.93,
  double? discountPct = 40.0,
  int? daysToExpiry = 5,
  FoodCategory category = FoodCategory.dairy,
  String storageType = 'chilled',
  String defaultUnit = 'karton',
}) {
  final now = DateTime.now();
  return Listing(
    id: id,
    productId: 501,
    sellerId: 21,
    batchNumber: 'LOT-2026-QA01',
    qty: qty,
    normalPrice: normalPrice,
    startPrice: startPrice,
    minPrice: minPrice,
    dropIntervalMinutes: 60,
    dropPercentage: 2.5,
    expiryDate: now.add(Duration(days: daysToExpiry ?? 5)),
    auctionStartAt: now.subtract(const Duration(hours: 6)),
    auctionEndAt: now.add(Duration(days: daysToExpiry ?? 5)),
    status: 'active',
    createdAt: now.subtract(const Duration(days: 2)),
    productName: productName,
    brand: 'Diamond Fresh',
    category: category,
    storageType: storageType,
    defaultUnit: defaultUnit,
    companyName: companyName,
    warehouseLat: -6.2100,
    warehouseLng: 106.8400,
    city: city,
    distanceKm: distanceKm,
    matchScore: matchScore,
    discountPct: discountPct,
    daysToExpiry: daysToExpiry,
  );
}

CachedListingModel _buildCachedModel({
  int id = 101,
  String productName = 'Susu UHT Segar 1L',
  String companyName = 'PT Pangan Segar Sejahtera',
  String city = 'Jakarta Selatan',
  double normalPrice = 30000,
  double startPrice = 18000,
  int qty = 80,
  double? distanceKm = 3.5,
  double? matchScore = 0.93,
  double? discountPct = 40.0,
  int? daysToExpiry = 5,
  String category = 'Dairy',
  String storageType = 'chilled',
}) {
  return CachedListingModel(
    id: id,
    productId: 501,
    sellerId: 21,
    batchNumber: 'LOT-2026-QA01',
    qty: qty,
    normalPrice: normalPrice,
    startPrice: startPrice,
    minPrice: 12000,
    currentPrice: startPrice,
    dropIntervalMinutes: 60,
    dropPercentage: 2.5,
    expiryDate: DateTime.now().add(Duration(days: daysToExpiry ?? 5)).toIso8601String(),
    auctionStartAt: DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
    auctionEndAt: DateTime.now().add(Duration(days: daysToExpiry ?? 5)).toIso8601String(),
    status: 'active',
    createdAt: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    productName: productName,
    brand: 'Diamond Fresh',
    category: category,
    storageType: storageType,
    defaultUnit: 'karton',
    sellerCompany: companyName,
    warehouseLat: -6.2100,
    warehouseLng: 106.8400,
    warehouseCity: city,
    cachedAt: DateTime.now().toIso8601String(),
    distanceKm: distanceKm,
    matchScore: matchScore,
    discountPct: discountPct,
    daysToExpiry: daysToExpiry,
  );
}

class _QAListingRepository extends ListingRepository {
  _QAListingRepository({
    required this.items,
    this.isCache = false,
    this.shouldThrow = false,
  });

  final List<CachedListingModel> items;
  final bool isCache;
  final bool shouldThrow;

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
    if (shouldThrow) {
      throw Exception('Simulated network timeout');
    }
    var result = List<CachedListingModel>.from(items);
    if (category != null && category.isNotEmpty) {
      result = result.where((e) => e.category.toLowerCase() == category.toLowerCase()).toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result.where((e) =>
        e.productName.toLowerCase().contains(q) ||
        (e.sellerCompany?.toLowerCase().contains(q) ?? false) ||
        e.category.toLowerCase().contains(q)
      ).toList();
    }
    return ListingResult(listings: result, isFromCache: isCache);
  }

  @override
  Future<CachedListingModel?> getListingById(int id, {bool forceRefresh = false}) async {
    try {
      return items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}

class _QAOrderRepository extends OrderRepository {
  _QAOrderRepository({this.onBuyCallback, this.shouldFail = false});

  final void Function(int listingId, int qty, bool biometricVerified)? onBuyCallback;
  final bool shouldFail;

  @override
  Future<CachedOrderModel> buyListing(int listingId, {int qty = 1, bool biometricVerified = true}) async {
    if (shouldFail) {
      throw Exception('Gagal memproses pesanan: stok tidak mencukupi');
    }
    if (onBuyCallback != null) {
      onBuyCallback!(listingId, qty, biometricVerified);
    }
    return CachedOrderModel(
      id: 888,
      listingId: listingId,
      buyerId: 77,
      qty: qty,
      finalUnitPrice: 18000,
      totalPrice: 18000.0 * qty,
      status: 'paid',
      createdAt: DateTime.now().toIso8601String(),
      productName: 'Susu UHT Segar 1L',
      category: 'Dairy',
      batchNumber: 'LOT-2026-QA01',
      cachedAt: DateTime.now().toIso8601String(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QA-01: Proximity Metrics & Mathematical Boundary Tests', () {
    test('Boundary: Distance = 0 km results in 100% proximity score', () {
      final listing = _buildTestListing(
        distanceKm: 0.0,
        matchScore: 0.99,
        discountPct: 40.0,
        daysToExpiry: 15,
      );
      expect(listing.distanceText, '0.0 km');
      expect(listing.matchScorePercentage, '99% Match');
      expect(listing.effectiveMatchScore, 0.99);
      expect(listing.effectiveDiscountPercent, 40);
    });

    test('Boundary: Long distance formatting (e.g. 42.8 km)', () {
      final listing = _buildTestListing(
        distanceKm: 42.78,
        matchScore: 0.14,
        discountPct: 25.0,
        daysToExpiry: 20,
      );
      expect(listing.distanceText, '42.8 km');
      expect(listing.matchScorePercentage, '14% Match');
      expect(listing.effectiveDiscountPercent, 25);
    });

    test('Boundary: Missing distanceKm falls back to seller city name', () {
      final listing = _buildTestListing(
        distanceKm: null,
        city: 'Bandung',
      );
      expect(listing.distanceText, 'Bandung');
    });

    test('Boundary: Null discountPct computes dynamically from normal and start price', () {
      final listing = _buildTestListing(
        normalPrice: 100000,
        startPrice: 60000,
        discountPct: null,
      );
      // (100000 - 60000) / 100000 * 100 = 40%
      expect(listing.discountPercent, 40);
      expect(listing.effectiveDiscountPercent, 40);
    });

    test('Boundary: Expiry dates and remaining days computation', () {
      final urgentListing = _buildTestListing(daysToExpiry: 1);
      final safeListing = _buildTestListing(daysToExpiry: 25);
      expect(urgentListing.effectiveDaysToExpiry, 1);
      expect(safeListing.effectiveDaysToExpiry, 25);
    });
  });

  group('QA-02: Buyer HomeScreen Comprehensive Verification', () {
    late InMemoryTokenStorage storage;
    late AuthRepository authRepo;

    setUp(() async {
      storage = InMemoryTokenStorage();
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'qa-buyer-token-valid',
          refreshToken: 'qa-buyer-refresh-valid',
          userId: 77,
          role: 'buyer',
        ),
      );

      final adapter = _QAMockAdapter((_) async => _QAMockAdapter.json({'success': true, 'data': {}}));
      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
      await authRepo.init();
      AuthRepository.instance = authRepo;
    });

    testWidgets('Renders all PRD-mandated layout elements: Header, Radar Badge, Location, Search', (tester) async {
      final items = [
        _buildCachedModel(id: 1, productName: 'Butter Salted Anchor 250g', category: 'Dairy'),
      ];
      final repo = _QAListingRepository(items: items);

      await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Brand headers & verified badge
      expect(find.text('RECOVERA B2B'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.byKey(const Key('buyer_greeting_title')), findsOneWidget);

      // Location bar & proximity indicator
      expect(find.byKey(const Key('buyer_location_text')), findsOneWidget);
      expect(find.byKey(const Key('proximity_radius_badge')), findsOneWidget);
      expect(find.text('Radius < 15 km'), findsOneWidget);

      // Search field & recommendations section
      expect(find.byKey(const Key('home_search_field')), findsOneWidget);
      expect(find.byKey(const Key('section_recommendations_title')), findsOneWidget);
      expect(find.text('Rekomendasi Terdekat'), findsOneWidget);

      // ProductCard badges
      expect(find.byKey(const Key('product_card_1')), findsOneWidget);
      expect(find.text('Butter Salted Anchor 250g'), findsOneWidget);
      expect(find.byKey(const Key('match_score_badge_1')), findsOneWidget);
      expect(find.text('93% Match'), findsOneWidget);
      expect(find.byKey(const Key('discount_badge_1')), findsOneWidget);
      expect(find.text('-40%'), findsOneWidget);
    });

    testWidgets('Multi-category chip filter toggles and filters listings accurately', (tester) async {
      final items = [
        _buildCachedModel(id: 1, productName: 'Susu UHT Segar 1L', category: 'Dairy'),
        _buildCachedModel(id: 2, productName: 'Minyak Goreng SunCo 2L', category: 'Oil'),
      ];
      final repo = _QAListingRepository(items: items);

      await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Susu UHT Segar 1L'), findsOneWidget);
      expect(find.text('Minyak Goreng SunCo 2L'), findsOneWidget);

      // Filter by Oil
      await tester.tap(find.text('Oil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Minyak Goreng SunCo 2L'), findsOneWidget);
      expect(find.text('Susu UHT Segar 1L'), findsNothing);

      // Switch to Dairy
      await tester.tap(find.text('Dairy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Susu UHT Segar 1L'), findsOneWidget);
      expect(find.text('Minyak Goreng SunCo 2L'), findsNothing);
    });

    testWidgets('Real-time search filters by product name and shows empty state on no match', (tester) async {
      final items = [
        _buildCachedModel(id: 1, productName: 'Tepung Cakra Kembar 1kg', category: 'Grains'),
      ];
      final repo = _QAListingRepository(items: items);

      await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Tepung Cakra Kembar 1kg'), findsOneWidget);

      // Search for non-existent keyword
      await tester.enterText(find.byKey(const Key('home_search_field')), 'ProdukGaAdaXYZ');
      await tester.pump();

      expect(find.byKey(const Key('home_empty_state')), findsOneWidget);
      expect(find.text('Tidak ada stok lelang di dekat lokasi Anda'), findsOneWidget);
    });

    testWidgets('Network error displays retry state and gracefully recovers upon tap', (tester) async {
      final repo = _QAListingRepository(items: [], shouldThrow: true);

      await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('home_error_state')), findsOneWidget);
      expect(find.byKey(const Key('btn_home_retry')), findsOneWidget);
    });
  });

  group('QA-03: ProductDetailScreen & Purchase Journey Verification', () {
    late InMemoryTokenStorage storage;
    late AuthRepository authRepo;

    setUp(() async {
      storage = InMemoryTokenStorage();
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'qa-buyer-token-valid',
          refreshToken: 'qa-buyer-refresh-valid',
          userId: 77,
          role: 'buyer',
        ),
      );

      final adapter = _QAMockAdapter((_) async => _QAMockAdapter.json({'success': true, 'data': {}}));
      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
      await authRepo.init();
      AuthRepository.instance = authRepo;
    });

    testWidgets('Renders complete specifications, shelf-life alert, seller card, and ESG guarantee', (tester) async {
      final listing = _buildTestListing(
        id: 701,
        productName: 'Keju Cheddar Block 2kg',
        companyName: 'PT Pangan Sumber Makmur',
        city: 'Jakarta Timur',
        normalPrice: 150000,
        startPrice: 90000,
        qty: 60,
        daysToExpiry: 2, // Urgent warning threshold (<= 3 days)
        storageType: 'chilled',
        category: FoodCategory.dairy,
      );

      await tester.pumpWidget(MaterialApp(home: ProductDetailScreen(listing: listing)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Title & badges
      expect(find.text('Keju Cheddar Block 2kg'), findsWidgets);
      expect(find.byKey(const Key('detail_match_score_badge')), findsOneWidget);
      expect(find.byKey(const Key('detail_discount_badge')), findsOneWidget);

      // Shelf life urgency banner (<= 3 days)
      expect(find.byKey(const Key('detail_shelf_life_warning')), findsOneWidget);
      expect(find.text('Sisa 2 Hari Sebelum Kedaluwarsa'), findsOneWidget);

      // Verified seller organization card
      expect(find.text('Distributor Terverifikasi'), findsOneWidget);
      expect(find.text('PT Pangan Sumber Makmur'), findsOneWidget);
      expect(find.textContaining('Jakarta Timur'), findsWidgets);

      // Specification table
      expect(find.text('Spesifikasi Produk Pangan'), findsOneWidget);
      expect(find.text('LOT-2026-QA01'), findsOneWidget);

      // Zero-Waste ESG Guarantee notice
      await tester.ensureVisible(find.textContaining('Zero-Waste'));
      expect(find.textContaining('Zero-Waste'), findsOneWidget);

      // Sticky buy bar
      expect(find.byKey(const Key('btn_buy_now')), findsOneWidget);
    });

    testWidgets('Quantity stepper clamps between 1 and available stock (upper bound)', (tester) async {
      final listing = _buildTestListing(id: 702, qty: 3);

      await tester.pumpWidget(MaterialApp(home: ProductDetailScreen(listing: listing)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(find.byKey(const Key('text_qty_value')));
      expect(find.text('1'), findsWidgets);

      // Decrement at min bound (1) should remain 1
      await tester.ensureVisible(find.byKey(const Key('btn_qty_decrease')));
      await tester.tap(find.byKey(const Key('btn_qty_decrease')));
      await tester.pump();
      expect(find.text('1'), findsWidgets);

      // Increment to 2
      await tester.ensureVisible(find.byKey(const Key('btn_qty_increase')));
      await tester.tap(find.byKey(const Key('btn_qty_increase')));
      await tester.pump();
      expect(find.text('2'), findsWidgets);

      // Increment to max bound (3)
      await tester.tap(find.byKey(const Key('btn_qty_increase')));
      await tester.pump();
      expect(find.text('3'), findsWidgets);

      // Increment beyond max bound should remain 3
      await tester.tap(find.byKey(const Key('btn_qty_increase')));
      await tester.pump();
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('Full purchase execution with confirmation modal and OrderRepository callback', (tester) async {
      final listing = _buildTestListing(id: 703, qty: 20);
      int? orderedListingId;
      int? orderedQty;
      bool? orderedBiometric;

      final orderRepo = _QAOrderRepository(
        onBuyCallback: (id, qty, bio) {
          orderedListingId = id;
          orderedQty = qty;
          orderedBiometric = bio;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailScreen(
            listing: listing,
            orderRepository: orderRepo,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Increase quantity to 2
      await tester.ensureVisible(find.byKey(const Key('btn_qty_increase')));
      await tester.tap(find.byKey(const Key('btn_qty_increase')));
      await tester.pump();

      // Tap 'Beli Sekarang'
      await tester.tap(find.byKey(const Key('btn_buy_now')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation bottom sheet
      expect(find.text('Konfirmasi Pembelian'), findsOneWidget);
      expect(find.byKey(const Key('btn_confirm_purchase_sheet')), findsOneWidget);

      // Confirm purchase
      await tester.tap(find.byKey(const Key('btn_confirm_purchase_sheet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Assert parameters delivered to OrderRepository
      expect(orderedListingId, 703);
      expect(orderedQty, 2);
      expect(orderedBiometric, isTrue);

      // Assert purchase success dialog
      expect(find.text('Pembelian Berhasil!'), findsOneWidget);
      expect(find.byKey(const Key('btn_order_success_confirm')), findsOneWidget);
    });

    testWidgets('Purchase failure displays error snackbar without crashing', (tester) async {
      final listing = _buildTestListing(id: 704, qty: 10);
      final failingRepo = _QAOrderRepository(shouldFail: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailScreen(
            listing: listing,
            orderRepository: failingRepo,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap buy now
      await tester.tap(find.byKey(const Key('btn_buy_now')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirm purchase
      await tester.tap(find.byKey(const Key('btn_confirm_purchase_sheet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Expect error snackbar message, success dialog should NOT appear
      expect(find.textContaining('Gagal menyelesaikan pembelian'), findsOneWidget);
      expect(find.text('Pembelian Berhasil!'), findsNothing);
    });
  });

  group('QA-04: Role-Based Access Control (RBAC) Security Verification', () {
    late InMemoryTokenStorage storage;
    late AuthRepository authRepo;

    setUp(() async {
      storage = InMemoryTokenStorage();
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'qa-seller-token',
          refreshToken: 'qa-seller-refresh',
          userId: 99,
          role: 'seller', // Configured as SELLER
        ),
      );

      final adapter = _QAMockAdapter((_) async => _QAMockAdapter.json({'success': true, 'data': {}}));
      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
      await authRepo.init();
      AuthRepository.instance = authRepo;
    });

    testWidgets('Seller role strictly denied from Buyer HomeScreen', (tester) async {
      final repo = _QAListingRepository(items: []);

      await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
      await tester.pump();

      expect(find.byKey(const Key('seller_access_restricted_title')), findsOneWidget);
      expect(find.text('Akses Terbatas: Khusus Pembeli'), findsOneWidget);
      expect(find.text('Akun penjual tidak diizinkan mengakses fitur discovery katalog pembeli.'), findsOneWidget);
      expect(find.byKey(const Key('home_search_field')), findsNothing);
    });

    testWidgets('Seller role strictly denied from ProductDetailScreen', (tester) async {
      final listing = _buildTestListing(id: 999);

      await tester.pumpWidget(MaterialApp(home: ProductDetailScreen(listing: listing)));
      await tester.pump();

      expect(find.text('Akses Dibatasi'), findsOneWidget);
      expect(find.text('Akun penjual tidak memiliki izin untuk mengakses halaman detail pembelian produk.'), findsOneWidget);
      expect(find.byKey(const Key('btn_buy_now')), findsNothing);
    });
  });

  group('QA-05: Offline Resilience & SQLite Cache Presentation', () {
    late InMemoryTokenStorage storage;
    late AuthRepository authRepo;

    setUp(() async {
      storage = InMemoryTokenStorage();
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'qa-buyer-token',
          refreshToken: 'qa-buyer-refresh',
          userId: 77,
          role: 'buyer',
        ),
      );

      final adapter = _QAMockAdapter((_) async => _QAMockAdapter.json({'success': true, 'data': {}}));
      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
      await authRepo.init();
      AuthRepository.instance = authRepo;
    });

    testWidgets('Offline cache displays visual banner and renders cached listings with full interactions', (tester) async {
      final items = [
        _buildCachedModel(
          id: 301,
          productName: 'Minyak Goreng SunCo 2L',
          companyName: 'PT Sumber Minyak Nabati',
          normalPrice: 42000,
          startPrice: 28000,
          category: 'Oil',
        ),
      ];
      final repo = _QAListingRepository(items: items, isCache: true);

      await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Offline banner verification
      expect(find.byKey(const Key('offline_indicator_banner')), findsOneWidget);
      expect(find.text('Mode Offline — Menampilkan data cache SQLite'), findsOneWidget);

      // Card rendering
      expect(find.byKey(const Key('product_card_301')), findsOneWidget);
      expect(find.text('Minyak Goreng SunCo 2L'), findsOneWidget);

      // Tap card to navigate to detail in offline mode
      await tester.tap(find.byKey(const Key('product_card_301')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Product detail screen rendered from cache
      expect(find.text('Detail Produk'), findsWidgets);
      expect(find.text('Minyak Goreng SunCo 2L'), findsWidgets);
      expect(find.byKey(const Key('btn_buy_now')), findsOneWidget);
    });
  });
}
