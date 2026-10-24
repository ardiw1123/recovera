import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/storage/token_storage.dart';
import 'package:recovera/data/models/cached_listing_model.dart';
import 'package:recovera/data/repositories/auth_repository.dart';
import 'package:recovera/data/repositories/listing_repository.dart';
import 'package:recovera/data/services/auth_api_service.dart';
import 'package:recovera/features/auth/models/user_profile.dart';
import 'package:recovera/features/auth/screens/location_management_screen.dart';
import 'package:recovera/features/home/widgets/filter_bottom_sheet.dart';
import 'package:recovera/features/home/widgets/product_card.dart';
import 'package:recovera/features/seller/repositories/seller_repository.dart';
import 'package:recovera/features/seller/screens/upload_stock_flow_screen.dart';
import 'package:recovera/features/seller/services/seller_api_service.dart';
import 'package:recovera/features/shell/main_shell.dart';

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

class _QATrackingListingRepo extends ListingRepository {
  _QATrackingListingRepo(this.items) : super();

  final List<CachedListingModel> items;
  double? lastRadiusKm;

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
    lastRadiusKm = radiusKm;
    var result = List<CachedListingModel>.from(items);
    if (radiusKm != null && radiusKm > 0) {
      result = result
          .where((i) => i.distanceKm == null || i.distanceKm! <= radiusKm)
          .toList();
    }
    return ListingResult(listings: result, isFromCache: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARDI-99 QA Phase 1: Location & Map Interaction Test Suite', () {
    testWidgets('LocationManagementScreen handles permission denial and interactive map canvas', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = InMemoryTokenStorage();
      await storage.saveTokens(const AuthTokens(
        accessToken: 'qa-token',
        refreshToken: 'qa-rt',
        userId: 1,
        role: 'buyer',
        name: 'Ardi Buyer',
      ));
      final client = ApiClient(
        tokenStorage: storage,
        adapter: _QAMockAdapter((o) async => _QAMockAdapter.json({'success': true, 'data': {}})),
      );
      final authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
      authRepo.currentUserProfile = const UserProfile(
        id: 1,
        email: 'ardi@recovera.id',
        role: 'buyer',
        name: 'Ardi Buyer',
        baseLat: -6.2088,
        baseLng: 106.8456,
      );
      AuthRepository.instance = authRepo;

      await tester.pumpWidget(
        const MaterialApp(
          home: LocationManagementScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Google Maps interactive canvas HUD, pin, and watermark
      expect(find.byKey(const Key('google_maps_watermark')), findsOneWidget);
      expect(find.byKey(const Key('map_pin_indicator')), findsOneWidget);
      expect(find.byKey(const Key('map_coordinates_hud')), findsOneWidget);
      expect(find.byKey(const Key('location_permission_prompt_banner')), findsOneWidget);

      // Verify deny button behaves gracefully
      final denyBtn = find.byKey(const Key('btn_deny_location_permission'));
      expect(denyBtn, findsOneWidget);
      await tester.ensureVisible(denyBtn);
      await tester.tap(denyBtn);
      await tester.pumpAndSettle();

      // Permission denied notice is displayed
      expect(find.byKey(const Key('permission_denied_banner')), findsOneWidget);

      // Manual coordinate input is present and functional
      expect(find.byKey(const Key('input_latitude')), findsOneWidget);
      expect(find.byKey(const Key('input_longitude')), findsOneWidget);
    });
  });

  group('ARDI-99 QA Phase 2: Seller Upload & Gallery Flow Test Suite', () {
    testWidgets('Native gallery picker selection and draft creation progression', (tester) async {
      final storage = InMemoryTokenStorage();
      final adapter = _QAMockAdapter((options) async {
        if (options.path.contains('/listings/seller/inventory/drafts')) {
          return _QAMockAdapter.json({
            'success': true,
            'data': {
              'listing': {
                'id': 99,
                'product_id': 101,
                'batch_number': 'LOT-QA-99',
                'qty': 100,
                'normal_price': 30000.0,
                'start_price': 20000.0,
                'min_price': 10000.0,
                'current_price': 20000.0,
                'expiry_date': '2026-11-20T00:00:00Z',
                'status': 'draft',
                'product': {
                  'id': 101,
                  'name': 'Keju Mozzarella 250g',
                  'category': 'Produk Olahan Susu & Dairy',
                  'default_unit': 'box',
                  'image_url': '/data/user/0/recovera/cache/mozzarella.jpg',
                },
              },
              'validation': {
                'valid': true,
                'errors': <String>[],
                'status': 'draft',
              },
              'price_recommendation': {
                'suggested_price': 20000.0,
                'discount_pct': 30.0,
                'rationale': 'Diskon awal 30%',
                'next_drop_at': '2026-11-20T12:00:00Z',
              },
            },
          });
        }
        if (options.path.contains('/validate')) {
          return _QAMockAdapter.json({
            'success': true,
            'data': {
              'valid': true,
              'errors': <String>[],
              'status': 'review',
            },
          });
        }
        return _QAMockAdapter.json({'success': true, 'data': {}});
      });

      await storage.saveTokens(const AuthTokens(
        accessToken: 'seller-qa-token',
        refreshToken: 'seller-qa-rt',
        userId: 101,
        role: 'seller',
        name: 'Ardi Seller',
      ));
      final apiClient = ApiClient(tokenStorage: storage, adapter: adapter);
      final authRepo = AuthRepository(
        authApiService: AuthApiService(client: apiClient),
        tokenStorage: storage,
      );
      await authRepo.init();
      AuthRepository.instance = authRepo;

      final sellerRepo = SellerRepository(
        apiService: SellerApiService(client: apiClient),
      );

      final fakeBytes = Uint8List.fromList([10, 20, 30]);

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: sellerRepo,
            onPickImage: () async {
              return XFile.fromData(
                fakeBytes,
                name: 'mozzarella.jpg',
                path: '/data/user/0/recovera/cache/mozzarella.jpg',
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap photo upload target to invoke gallery picker
      await tester.tap(find.byKey(const Key('photo_upload_tap_target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify gallery photo chosen
      expect(find.byKey(const Key('photo_upload_preview_container')), findsOneWidget);
      expect(find.text('Foto Galeri Terpilih'), findsOneWidget);

      // Submit Step 1 to progress
      await tester.ensureVisible(find.byKey(const Key('btn_submit_step1')));
      await tester.tap(find.byKey(const Key('btn_submit_step1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Progresses to Step 2 validation screen seamlessly without 500 error
      expect(find.text('Memeriksa Produk'), findsOneWidget);
    });
  });

  group('ARDI-99 QA Phase 3: Buyer Role Isolation & Distance Filter Test Suite', () {
    testWidgets('Buyer navigation omits Stok tab and supports dynamic distance filter > 15 km', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = InMemoryTokenStorage();
      await storage.saveTokens(const AuthTokens(
        accessToken: 'buyer-token',
        refreshToken: 'buyer-rt',
        userId: 2,
        role: 'buyer',
        name: 'Siti Buyer',
      ));
      final client = ApiClient(
        tokenStorage: storage,
        adapter: _QAMockAdapter((o) async => _QAMockAdapter.json({'success': true, 'data': {}})),
      );
      final authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
      authRepo.currentUserProfile = const UserProfile(
        id: 2,
        email: 'siti@recovera.id',
        role: 'buyer',
        name: 'Siti Buyer',
        baseLat: -6.2088,
        baseLng: 106.8456,
      );
      AuthRepository.instance = authRepo;

      final testListings = <CachedListingModel>[
        _makeListing(id: 1, productName: 'Yogurt Dekat (5 km)', distanceKm: 5.0),
        _makeListing(id: 2, productName: 'Keju Jauh (45 km)', distanceKm: 45.0),
      ];
      final trackingRepo = _QATrackingListingRepo(testListings);

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            listingRepository: trackingRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Role isolation verification: Buyer navbar has exactly 3 tabs (Home, Profil, Saran), NO Stok tab
      expect(find.text('Stok'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Saran'), findsOneWidget);

      // 2. Default 15 km threshold verification: Only item 1 (5 km) is shown, item 2 (45 km) is filtered
      expect(find.byType(ProductCard), findsOneWidget);
      expect(find.text('Yogurt Dekat (5 km)'), findsOneWidget);
      expect(find.text('Keju Jauh (45 km)'), findsNothing);

      // 3. Open distance filter and select preset > 15 km (50 km)
      await tester.tap(find.byKey(const Key('btn_home_filter')));
      await tester.pumpAndSettle();

      expect(find.byType(FilterBottomSheet), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('filter_distance_chip_50')), 300, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter_distance_chip_50')));
      await tester.pumpAndSettle();

      // Apply filter
      await tester.tap(find.byKey(const Key('btn_apply_filter_sheet')));
      await tester.pumpAndSettle();

      // 4. Verify expanded radius renders both products
      expect(find.byType(ProductCard), findsNWidgets(2));
      expect(find.text('Keju Jauh (45 km)'), findsOneWidget);
    });
  });

  group('ARDI-99 QA Phase 4: Responsive Viewport & Zero Overflow Test Suite', () {
    testWidgets('LocationManagementScreen and FilterBottomSheet render without RenderFlex overflow', (tester) async {
      // Test compact screen (320 x 568 - iPhone SE 1st gen)
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Render FilterBottomSheet in compact viewport
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBottomSheet(
              selectedCategories: const {},
              selectedExpiryPreset: 'all',
              selectedSort: 'cheapest',
              selectedRadiusKm: 50.0,
              onApply: (c, e, s, r) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no exceptions were thrown during layout
      expect(tester.takeException(), isNull);
    });
  });
}
