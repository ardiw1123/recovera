import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recovera/data/data.dart';
import 'package:recovera/features/auth/screens/location_management_screen.dart';
import 'package:recovera/features/auth/screens/profile_screen.dart';
import 'package:recovera/features/home/screens/home_screen.dart';
import 'package:recovera/features/home/widgets/product_card.dart';

class _QAMockAdapter implements HttpClientAdapter {
  _QAMockAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(
    Map<String, dynamic> data, {
    int statusCode = 200,
  }) {
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(data)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _QAListingRepository extends ListingRepository {
  _QAListingRepository(this._listings);

  List<CachedListingModel> _listings;
  double? lastRequestedLat;
  double? lastRequestedLng;

  void updateListings(List<CachedListingModel> newListings) {
    _listings = newListings;
  }

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
    lastRequestedLat = lat;
    lastRequestedLng = lng;
    return ListingResult(listings: _listings, isFromCache: false);
  }

  @override
  Future<CachedListingModel?> getListingById(int id, {bool forceRefresh = false}) async {
    return _listings.firstWhere((item) => item.id == id, orElse: () => _listings.first);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('QA-BL-01: Diagnostic & Initial Defect Verification (ardi@gmail.com)', () {
    late InMemoryTokenStorage tokenStorage;

    setUp(() async {
      tokenStorage = InMemoryTokenStorage();
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'ardi-jwt-token',
          refreshToken: 'ardi-refresh-token',
          userId: 101,
          role: 'buyer',
          name: 'Ardi Gunawan',
        ),
      );
    });

    testWidgets(
      'Verifies initial unconfigured location state and navigation from ProfileScreen',
      (tester) async {
        final client = ApiClient(
          tokenStorage: tokenStorage,
          adapter: _QAMockAdapter((options) async => _QAMockAdapter.json({'success': true, 'data': {}})),
        );

        final repo = AuthRepository(
          authApiService: AuthApiService(client: client),
          tokenStorage: tokenStorage,
        );
        await repo.init();

        // 1. Initial defect verification: account ardi@gmail.com starts with default coordinates
        repo.currentUserProfile = const UserProfile(
          id: 101,
          email: 'ardi@gmail.com',
          role: 'buyer',
          name: 'Ardi Gunawan',
          phone: '+6281234567890',
          address: 'Jl. Belum Ditetapkan No. 1, Jakarta',
          city: 'Jakarta',
          baseLat: -6.2088,
          baseLng: 106.8456,
        );
        AuthRepository.instance = repo;

        await tester.pumpWidget(
          MaterialApp(
            routes: {
              '/profile/location': (_) => const LocationManagementScreen(),
            },
            home: const ProfileScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Verify account info
        expect(find.text('Ardi Gunawan'), findsOneWidget);
        expect(find.text('ardi@gmail.com'), findsOneWidget);

        // Verify "Lokasi & Pengiriman" menu tile is rendered with current address subtitle
        expect(find.byKey(const Key('menu_location_and_delivery')), findsOneWidget);
        expect(find.text('Lokasi & Pengiriman'), findsOneWidget);
        expect(find.text('Jl. Belum Ditetapkan No. 1, Jakarta'), findsOneWidget);

        // Tap menu to navigate to LocationManagementScreen
        await tester.tap(find.byKey(const Key('menu_location_and_delivery')));
        await tester.pumpAndSettle();

        // Verify LocationManagementScreen is displayed
        expect(find.byType(LocationManagementScreen), findsOneWidget);
        expect(find.text('Atur Lokasi Pengiriman'), findsOneWidget);
        expect(find.byKey(const Key('btn_save_location')), findsOneWidget);
      },
    );
  });

  group('QA-BL-02: Google Maps Phone Canvas, Zoom, Pan & City Presets', () {
    late InMemoryTokenStorage tokenStorage;

    setUp(() async {
      tokenStorage = InMemoryTokenStorage();
      final client = ApiClient(
        tokenStorage: tokenStorage,
        adapter: _QAMockAdapter((options) async => _QAMockAdapter.json({'success': true, 'data': {}})),
      );
      final repo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: tokenStorage,
      );
      await repo.init();
      repo.currentUserProfile = const UserProfile(
        id: 101,
        email: 'ardi@gmail.com',
        role: 'buyer',
        name: 'Ardi Gunawan',
        address: 'Jl. Gatot Subroto No. 45, Jakarta Pusat',
        city: 'Jakarta Pusat',
        baseLat: -6.1754,
        baseLng: 106.8272,
      );
      AuthRepository.instance = repo;
    });

    testWidgets(
      'Google Maps canvas controls (zoom, pan, HUD, preset city chips) behave accurately',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: LocationManagementScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify canvas UI elements
        expect(find.byKey(const Key('google_maps_watermark')), findsOneWidget);
        expect(find.byKey(const Key('map_pin_indicator')), findsOneWidget);
        expect(find.byKey(const Key('map_coordinates_hud')), findsOneWidget);

        // 2. Zoom Controls
        await tester.tap(find.byKey(const Key('btn_zoom_in')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_zoom_out')));
        await tester.pumpAndSettle();

        // 3. Pan / Drag map canvas
        final mapFinder = find.byKey(const Key('map_touch_detector'));
        expect(mapFinder, findsOneWidget);
        await tester.drag(mapFinder, const Offset(30.0, -20.0));
        await tester.pumpAndSettle();

        // 4. Select Surabaya preset city chip
        final sbyChipFinder = find.byKey(const Key('chip_city_Surabaya'));
        expect(sbyChipFinder, findsOneWidget);
        await tester.tap(sbyChipFinder);
        await tester.pumpAndSettle();

        // Verify coordinate fields updated to Surabaya coordinates
        final latField = tester.widget<TextFormField>(find.byKey(const Key('input_latitude')));
        final lngField = tester.widget<TextFormField>(find.byKey(const Key('input_longitude')));
        expect(latField.controller?.text, '-7.257500');
        expect(lngField.controller?.text, '112.752100');

        final cityField = tester.widget<TextFormField>(find.byKey(const Key('input_city')));
        expect(cityField.controller?.text, 'Surabaya');
      },
    );
  });

  group('QA-BL-03: GPS Integration & Location Permission Boundary', () {
    late InMemoryTokenStorage tokenStorage;

    setUp(() async {
      tokenStorage = InMemoryTokenStorage();
      final client = ApiClient(
        tokenStorage: tokenStorage,
        adapter: _QAMockAdapter((options) async => _QAMockAdapter.json({'success': true, 'data': {}})),
      );
      final repo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: tokenStorage,
      );
      await repo.init();
      AuthRepository.instance = repo;
    });

    testWidgets(
      'GPS button acquires position when granted; handles denial gracefully with warning banner',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: LocationManagementScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Success GPS flow
        await tester.tap(find.byKey(const Key('btn_my_gps_location')));
        await tester.pump();
        expect(find.byKey(const Key('snack_gps_success')), findsOneWidget);
        await tester.pumpAndSettle();

        // 2. Permission denial simulation
        await tester.tap(find.byKey(const Key('toggle_permission_denial')));
        await tester.pumpAndSettle();

        // Warning banner must now be visible
        expect(find.byKey(const Key('banner_permission_warning')), findsOneWidget);

        // Tap GPS button again -> shows permission denied snackbar, no crash
        await tester.tap(find.byKey(const Key('btn_my_gps_location')));
        await tester.pump();
        expect(find.byKey(const Key('snack_permission_denial')), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );
  });

  group('QA-BL-04: Form Validation & Persistence Contract (PATCH /profile)', () {
    late InMemoryTokenStorage tokenStorage;

    setUp(() async {
      tokenStorage = InMemoryTokenStorage();
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'test-token',
          refreshToken: 'test-rt',
          userId: 101,
          role: 'buyer',
          name: 'Ardi Gunawan',
        ),
      );
    });

    testWidgets(
      'Validates invalid inputs; submits valid location via PATCH /profile with correct body',
      (tester) async {
        Map<String, dynamic>? interceptedBody;
        String? interceptedMethod;

        final adapter = _QAMockAdapter((options) async {
          interceptedMethod = options.method;
          interceptedBody = options.data as Map<String, dynamic>?;

          return _QAMockAdapter.json({
            'success': true,
            'data': {
              'id': 101,
              'email': 'ardi@gmail.com',
              'role': 'buyer',
              'name': 'Ardi Gunawan',
              'buyer': {
                'id': 10,
                'business_type': 'resto',
                'address': 'Jl. Kemang Raya No. 18, Jakarta Selatan',
                'base_lat': -6.2615,
                'base_lng': 106.8106,
                'pref_categories': ['Dairy'],
                'max_radius_km': 15,
                'has_cold_storage': false,
                'total_orders_completed': 0,
                'payment_reliability_score': 1.0,
              },
            },
          });
        });

        final client = ApiClient(tokenStorage: tokenStorage, adapter: adapter);
        final repo = AuthRepository(
          authApiService: AuthApiService(client: client),
          tokenStorage: tokenStorage,
        );
        await repo.init();
        repo.currentUserProfile = const UserProfile(
          id: 101,
          email: 'ardi@gmail.com',
          role: 'buyer',
          name: 'Ardi Gunawan',
          address: 'Jl. Lama',
          city: 'Jakarta',
          baseLat: -6.2088,
          baseLng: 106.8456,
        );
        AuthRepository.instance = repo;

        await tester.pumpWidget(
          const MaterialApp(
            home: LocationManagementScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Switch to manual mode
        await tester.tap(find.byKey(const Key('toggle_map_mode')));
        await tester.pumpAndSettle();

        // 2. Test validation: clear address and submit
        await tester.enterText(find.byKey(const Key('input_address')), '');
        await tester.tap(find.byKey(const Key('btn_save_location')));
        await tester.pumpAndSettle();
        expect(find.text('Alamat tidak boleh kosong'), findsOneWidget);

        // 3. Test validation: out of range latitude (> 90)
        await tester.enterText(find.byKey(const Key('input_address')), 'Jl. Valid');
        await tester.enterText(find.byKey(const Key('input_latitude')), '150.0');
        await tester.tap(find.byKey(const Key('btn_save_location')));
        await tester.pumpAndSettle();
        expect(find.text('Latitude harus di antara -90 dan 90'), findsOneWidget);

        // 4. Fill valid data (Jakarta Selatan preset)
        await tester.tap(find.byKey(const Key('chip_city_Jakarta Selatan')));
        await tester.pumpAndSettle();

        // Save
        await tester.tap(find.byKey(const Key('btn_save_location')));
        await tester.pump();

        // Verify PATCH call parameters
        expect(interceptedMethod, 'PATCH');
        expect(interceptedBody?['address'], 'Jl. Kemang Raya No. 18, Jakarta Selatan');
        expect(interceptedBody?['base_lat'], -6.2615);
        expect(interceptedBody?['base_lng'], 106.8106);
        expect(interceptedBody?['city'], 'Jakarta Selatan');

        // Verify toast and profile update
        expect(find.byKey(const Key('snack_save_success')), findsOneWidget);
        expect(repo.currentUserProfile?.address, 'Jl. Kemang Raya No. 18, Jakarta Selatan');
        expect(repo.currentUserProfile?.baseLat, -6.2615);
        expect(repo.currentUserProfile?.baseLng, 106.8106);
      },
    );
  });

  group('QA-BL-05: Dynamic Home Screen & Proximity Re-calculation', () {
    late InMemoryTokenStorage tokenStorage;
    late _QAListingRepository listingRepo;

    final sampleListings = <CachedListingModel>[
      const CachedListingModel(
        id: 1,
        productId: 101,
        sellerId: 201,
        batchNumber: 'BATCH-001',
        productName: 'Keju Mozzarella Surabaya',
        category: 'Dairy',
        sellerCompany: 'PT Pangan Surabaya',
        warehouseCity: 'Surabaya',
        warehouseLat: -7.2575,
        warehouseLng: 112.7521,
        distanceKm: 0.8,
        matchScore: 0.95,
        currentPrice: 45000.0,
        startPrice: 55000.0,
        normalPrice: 60000.0,
        minPrice: 35000.0,
        qty: 50,
        defaultUnit: 'karton',
        status: 'active',
        daysToExpiry: 15,
        expiryDate: '2026-11-05',
        auctionStartAt: '2026-10-20T00:00:00Z',
        auctionEndAt: '2026-11-05T00:00:00Z',
        createdAt: '2026-10-20T00:00:00Z',
        cachedAt: '2026-10-20T00:00:00Z',
        storageType: 'chilled',
      ),
      const CachedListingModel(
        id: 2,
        productId: 102,
        sellerId: 202,
        batchNumber: 'BATCH-002',
        productName: 'Butter Anchor Jakarta',
        category: 'Dairy',
        sellerCompany: 'PT Pangan Jakarta',
        warehouseCity: 'Jakarta Pusat',
        warehouseLat: -6.1754,
        warehouseLng: 106.8272,
        distanceKm: 660.0,
        matchScore: 0.10,
        currentPrice: 70000.0,
        startPrice: 85000.0,
        normalPrice: 100000.0,
        minPrice: 50000.0,
        qty: 30,
        defaultUnit: 'karton',
        status: 'active',
        daysToExpiry: 20,
        expiryDate: '2026-11-10',
        auctionStartAt: '2026-10-20T00:00:00Z',
        auctionEndAt: '2026-11-10T00:00:00Z',
        createdAt: '2026-10-20T00:00:00Z',
        cachedAt: '2026-10-20T00:00:00Z',
        storageType: 'chilled',
      ),
    ];

    setUp(() async {
      tokenStorage = InMemoryTokenStorage();
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'buyer-token',
          refreshToken: 'buyer-rt',
          userId: 101,
          role: 'buyer',
          name: 'Ardi Gunawan',
        ),
      );

      final client = ApiClient(
        tokenStorage: tokenStorage,
        adapter: _QAMockAdapter((options) async => _QAMockAdapter.json({'success': true, 'data': {}})),
      );
      final authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: tokenStorage,
      );
      await authRepo.init();

      // Buyer starts with Surabaya location
      authRepo.currentUserProfile = const UserProfile(
        id: 101,
        email: 'ardi@gmail.com',
        role: 'buyer',
        name: 'Ardi Gunawan',
        address: 'Jl. Pemuda No. 33, Surabaya',
        city: 'Surabaya',
        baseLat: -7.2575,
        baseLng: 112.7521,
      );
      AuthRepository.instance = authRepo;

      listingRepo = _QAListingRepository(sampleListings);
    });

    testWidgets(
      'HomeScreen header reflects buyer location, passes coordinates to ListingRepository, and displays proximity',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            routes: {
              '/profile/location': (_) => const LocationManagementScreen(),
            },
            home: HomeScreen(
              userLat: -7.2575,
              userLng: 112.7521,
              repository: listingRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify location bar in header shows "Surabaya"
        expect(find.byKey(const Key('buyer_location_text')), findsOneWidget);
        expect(find.textContaining('Surabaya'), findsAtLeastNWidgets(1));

        // 2. Verify coordinates injected into ListingRepository query
        expect(listingRepo.lastRequestedLat, -7.2575);
        expect(listingRepo.lastRequestedLng, 112.7521);

        // 3. Verify proximity badge & listings rendered
        expect(find.byType(ProductCard), findsNWidgets(2));
        expect(find.text('Keju Mozzarella Surabaya'), findsOneWidget);
        expect(find.textContaining('0.8 km'), findsOneWidget);

        // 4. Tap location bar button to navigate to LocationManagementScreen
        await tester.tap(find.byKey(const Key('home_location_bar_button')));
        await tester.pumpAndSettle();

        expect(find.byType(LocationManagementScreen), findsOneWidget);
      },
    );
  });

  group('QA-BL-06: Network Disruption & Offline Cache Resilience', () {
    late InMemoryTokenStorage tokenStorage;

    setUp(() async {
      tokenStorage = InMemoryTokenStorage();
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'test-token',
          refreshToken: 'test-rt',
          userId: 101,
          role: 'buyer',
          name: 'Ardi Gunawan',
        ),
      );
    });

    testWidgets(
      'Network disconnection during save triggers graceful offline fallback without crash',
      (tester) async {
        final adapter = _QAMockAdapter((options) async {
          throw DioException(
            requestOptions: options,
            error: 'SocketException: Connection refused (offline)',
            type: DioExceptionType.connectionError,
          );
        });

        final client = ApiClient(tokenStorage: tokenStorage, adapter: adapter);
        final repo = AuthRepository(
          authApiService: AuthApiService(client: client),
          tokenStorage: tokenStorage,
        );
        await repo.init();
        repo.currentUserProfile = const UserProfile(
          id: 101,
          email: 'ardi@gmail.com',
          role: 'buyer',
          name: 'Ardi Gunawan',
          address: 'Jl. Alamat Awal Jakarta',
          city: 'Jakarta',
          baseLat: -6.2088,
          baseLng: 106.8456,
        );
        AuthRepository.instance = repo;

        await tester.pumpWidget(
          const MaterialApp(
            home: LocationManagementScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Switch city preset to Bandung
        await tester.tap(find.byKey(const Key('chip_city_Bandung')));
        await tester.pumpAndSettle();

        // Tap save during simulated network drop
        await tester.tap(find.byKey(const Key('btn_save_location')));
        await tester.pump();

        // Offline snackbar displayed
        expect(find.byKey(const Key('snack_save_offline')), findsOneWidget);
        expect(find.textContaining('Tersimpan di perangkat lokal'), findsOneWidget);

        // Local state preserved
        expect(repo.currentUserProfile?.city, 'Bandung');
        expect(repo.currentUserProfile?.baseLat, -6.9175);
        expect(repo.currentUserProfile?.baseLng, 107.6191);
      },
    );
  });
}
