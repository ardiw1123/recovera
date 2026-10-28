import 'dart:async';
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
import 'package:recovera/features/shell/main_shell.dart';

class _TestHttpAdapter implements HttpClientAdapter {
  _TestHttpAdapter(this.handler);

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

  static ResponseBody json(Map<String, dynamic> data, {int statusCode = 200}) {
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(data)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _TestListingRepo extends ListingRepository {
  _TestListingRepo();

  final List<CachedListingModel> listings = const [];
  double? lastRequestedLat;
  double? lastRequestedLng;

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
    return ListingResult(listings: listings, isFromCache: false);
  }

  @override
  Future<CachedListingModel?> getListingById(
    int id, {
    bool forceRefresh = false,
  }) async {
    return listings.isNotEmpty ? listings.first : null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('ARDI-90: UserProfile Coordinate Parsing & Data Model Tests', () {
    test('Parses buyer base_lat and base_lng correctly from numeric json', () {
      final json = {
        'id': 10,
        'email': 'buyer@recovera.id',
        'role': 'buyer',
        'name': 'Ardi Buyer',
        'buyer': {
          'id': 101,
          'business_type': 'bakery',
          'address': 'Jl. Margonda Raya No. 100, Depok',
          'base_lat': -6.4025,
          'base_lng': 106.7942,
          'pref_categories': ['Dairy'],
          'max_radius_km': 15,
        },
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 10);
      expect(profile.role, 'buyer');
      expect(profile.name, 'Ardi Buyer');
      expect(profile.address, 'Jl. Margonda Raya No. 100, Depok');
      expect(profile.baseLat, -6.4025);
      expect(profile.baseLng, 106.7942);
      expect(profile.lat, -6.4025);
      expect(profile.lng, 106.7942);
    });

    test('Parses seller warehouse_lat and warehouse_lng correctly', () {
      final json = {
        'id': 20,
        'email': 'seller@recovera.id',
        'role': 'seller',
        'name': 'Budi Seller',
        'seller': {
          'id': 201,
          'company_name': 'PT Pangan Sumber Makmur',
          'address': 'Kawasan Industri Rungkut, Surabaya',
          'warehouse_lat': -7.3100,
          'warehouse_lng': 112.7800,
          'city': 'Surabaya',
        },
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 20);
      expect(profile.role, 'seller');
      expect(profile.warehouseLat, -7.3100);
      expect(profile.warehouseLng, 112.7800);
      expect(profile.lat, -7.3100);
      expect(profile.lng, 112.7800);
    });

    test('Parses string-formatted coordinates safely without throwing', () {
      final json = {
        'id': 30,
        'email': 'string@recovera.id',
        'role': 'buyer',
        'name': 'String Coords User',
        'base_lat': '-6.2088',
        'base_lng': '106.8456',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.baseLat, -6.2088);
      expect(profile.baseLng, 106.8456);
      expect(profile.lat, -6.2088);
      expect(profile.lng, 106.8456);
    });

    test(
      'copyWith updates coordinates and address while preserving other fields',
      () {
        const initial = UserProfile(
          id: 1,
          email: 'test@example.com',
          role: 'buyer',
          name: 'Initial Name',
          address: 'Initial Address',
          city: 'Jakarta',
          baseLat: -6.2088,
          baseLng: 106.8456,
        );

        final updated = initial.copyWith(
          address: 'Jl. Pemuda No. 33, Surabaya',
          city: 'Surabaya',
          baseLat: -7.2575,
          baseLng: 112.7521,
        );

        expect(updated.id, 1);
        expect(updated.email, 'test@example.com');
        expect(updated.name, 'Initial Name');
        expect(updated.address, 'Jl. Pemuda No. 33, Surabaya');
        expect(updated.city, 'Surabaya');
        expect(updated.baseLat, -7.2575);
        expect(updated.baseLng, 112.7521);
        expect(updated.lat, -7.2575);
        expect(updated.lng, 112.7521);
      },
    );

    test('toJson serializes coordinates and profile fields', () {
      const profile = UserProfile(
        id: 42,
        email: 'ardi@gmail.com',
        role: 'buyer',
        name: 'Ardi Pratama',
        address: 'Jl. Margonda No. 42',
        city: 'Depok',
        baseLat: -6.4025,
        baseLng: 106.7942,
      );

      final map = profile.toJson();

      expect(map['id'], 42);
      expect(map['email'], 'ardi@gmail.com');
      expect(map['address'], 'Jl. Margonda No. 42');
      expect(map['base_lat'], -6.4025);
      expect(map['base_lng'], 106.7942);
    });
  });

  group('ARDI-90: AuthApiService & AuthRepository Location Update Tests', () {
    late InMemoryTokenStorage tokenStorage;

    setUp(() async {
      tokenStorage = InMemoryTokenStorage();
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'valid-test-access-token',
          refreshToken: 'valid-test-refresh-token',
          userId: 99,
          role: 'buyer',
          name: 'Ardi Gunawan',
        ),
      );
    });

    test('AuthApiService.updateLocation sends PATCH /profile with correct buyer payload', () async {
      Map<String, dynamic>? interceptedData;
      String? interceptedMethod;
      String? interceptedPath;

      final adapter = _TestHttpAdapter((options) async {
        interceptedMethod = options.method;
        interceptedPath = options.path;
        interceptedData = options.data as Map<String, dynamic>?;

        return _TestHttpAdapter.json({
          'success': true,
          'data': {
            'id': 99,
            'email': 'ardi@gmail.com',
            'role': 'buyer',
            'name': 'Ardi Gunawan',
            'buyer': {
              'id': 1,
              'business_type': 'resto',
              'address': 'Jl. Kemang Raya No. 18, Jakarta Selatan',
              'base_lat': -6.2615,
              'base_lng': 106.8106,
              'pref_categories': [],
              'max_radius_km': 15,
              'has_cold_storage': false,
              'total_orders_completed': 0,
              'payment_reliability_score': 1.0,
            },
          },
        });
      });

      final client = ApiClient(tokenStorage: tokenStorage, adapter: adapter);
      final apiService = AuthApiService(client: client);

      final result = await apiService.updateLocation(
        address: 'Jl. Kemang Raya No. 18, Jakarta Selatan',
        latitude: -6.2615,
        longitude: 106.8106,
        city: 'Jakarta Selatan',
        isSeller: false,
      );

      expect(interceptedMethod, 'PATCH');
      expect(interceptedPath, '/profile');
      expect(
        interceptedData?['address'],
        'Jl. Kemang Raya No. 18, Jakarta Selatan',
      );
      expect(interceptedData?['base_lat'], -6.2615);
      expect(interceptedData?['base_lng'], 106.8106);
      expect(interceptedData?['city'], 'Jakarta Selatan');

      expect(result.address, 'Jl. Kemang Raya No. 18, Jakarta Selatan');
      expect(result.baseLat, -6.2615);
      expect(result.baseLng, 106.8106);
    });

    test('AuthRepository.updateLocation syncs profile and triggers notifyListeners', () async {
      final adapter = _TestHttpAdapter((options) async {
        return _TestHttpAdapter.json({
          'success': true,
          'data': {
            'id': 99,
            'email': 'ardi@gmail.com',
            'role': 'buyer',
            'name': 'Ardi Gunawan',
            'buyer': {
              'id': 1,
              'business_type': 'resto',
              'address': 'Jl. Pemuda No. 33, Surabaya',
              'base_lat': -7.2575,
              'base_lng': 112.7521,
              'pref_categories': [],
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
      AuthRepository.instance = repo;

      int listenerNotificationCount = 0;
      repo.addListener(() {
        listenerNotificationCount++;
      });

      final updated = await repo.updateLocation(
        address: 'Jl. Pemuda No. 33, Surabaya',
        latitude: -7.2575,
        longitude: 112.7521,
        city: 'Surabaya',
      );

      expect(updated.address, 'Jl. Pemuda No. 33, Surabaya');
      expect(repo.currentUserProfile?.address, 'Jl. Pemuda No. 33, Surabaya');
      expect(repo.currentUserProfile?.baseLat, -7.2575);
      expect(repo.currentUserProfile?.baseLng, 112.7521);
      expect(listenerNotificationCount, greaterThan(0));
    });

    test('AuthRepository.updateLocation applies offline fallback on network failure', () async {
      final adapter = _TestHttpAdapter((options) async {
        throw DioException(
          requestOptions: options,
          error: 'Connection refused',
          type: DioExceptionType.connectionError,
        );
      });

      final client = ApiClient(tokenStorage: tokenStorage, adapter: adapter);
      final repo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: tokenStorage,
      );
      await repo.init();
      AuthRepository.instance = repo;

      try {
        await repo.updateLocation(
          address: 'Jl. Offline Cache No. 1, Yogyakarta',
          latitude: -7.7956,
          longitude: 110.3695,
          city: 'Yogyakarta',
          allowOfflineFallback: true,
        );
      } catch (_) {
        // Expected network exception
      }

      // Memory session profile must still hold the updated coordinates for smooth offline UX
      expect(
        repo.currentUserProfile?.address,
        'Jl. Offline Cache No. 1, Yogyakarta',
      );
      expect(repo.currentUserProfile?.baseLat, -7.7956);
      expect(repo.currentUserProfile?.baseLng, 110.3695);
    });
  });

  group('ARDI-90: ProfileScreen Menu & Location Navigation Tests', () {
    late InMemoryTokenStorage tokenStorage;
    late AuthRepository authRepo;

    setUp(() async {
      tokenStorage = InMemoryTokenStorage();
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'tok-123',
          refreshToken: 'ref-123',
          userId: 99,
          role: 'buyer',
          name: 'Ardi Buyer',
        ),
      );

      final adapter = _TestHttpAdapter((options) async {
        return _TestHttpAdapter.json({
          'success': true,
          'data': {
            'id': 99,
            'email': 'ardi@gmail.com',
            'role': 'buyer',
            'name': 'Ardi Buyer',
            'buyer': {
              'id': 1,
              'business_type': 'resto',
              'address': 'Jl. Margonda Raya No. 42, Depok',
              'base_lat': -6.4025,
              'base_lng': 106.7942,
              'pref_categories': [],
              'max_radius_km': 15,
              'has_cold_storage': false,
              'total_orders_completed': 0,
              'payment_reliability_score': 1.0,
            },
          },
        });
      });

      final client = ApiClient(tokenStorage: tokenStorage, adapter: adapter);
      authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: tokenStorage,
      );
      await authRepo.init();
      await authRepo.fetchProfile();
      AuthRepository.instance = authRepo;
    });

    testWidgets('Profile photo source sheet can be cancelled without changes', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('Ubah foto profil'));
      await tester.pumpAndSettle();

      expect(find.text('Ubah Foto Profil'), findsOneWidget);
      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('File & Gambar'), findsOneWidget);

      await tester.tap(find.text('Batal').last);
      await tester.pumpAndSettle();

      expect(find.text('Ubah Foto Profil'), findsNothing);
      expect(find.byTooltip('Ubah foto profil'), findsOneWidget);
    });

    testWidgets(
      'Tapping "Lokasi & Pengiriman" in Profile menu opens LocationManagementScreen',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byKey(const Key('menu_location_and_delivery')),
          findsOneWidget,
        );
        expect(find.text('Lokasi & Pengiriman'), findsOneWidget);
        expect(find.text('Jl. Margonda Raya No. 42, Depok'), findsOneWidget);

        await tester.tap(find.byKey(const Key('menu_location_and_delivery')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('location_management_screen')),
          findsOneWidget,
        );
        expect(find.text('Peta Interaktif Google Maps'), findsOneWidget);
      },
    );

    testWidgets('Sky Balance appears between security settings and feedback', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final security = find.byKey(const Key('menu_security_biometrics'));
      final skyBalance = find.byKey(const Key('menu_sky_balance'));
      final feedback = find.byKey(const Key('menu_feedback'));
      expect(security, findsOneWidget);
      expect(skyBalance, findsOneWidget);
      expect(feedback, findsOneWidget);
      expect(
        tester.getTopLeft(skyBalance).dy,
        greaterThan(tester.getTopLeft(security).dy),
      );
      expect(
        tester.getTopLeft(feedback).dy,
        greaterThan(tester.getTopLeft(skyBalance).dy),
      );

      await tester.ensureVisible(skyBalance);
      await tester.pump();
      await tester.tap(skyBalance);
      // The lobby runs a looping cloud animation, so settle frame by frame
      // instead of pumpAndSettle (which would never settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('How to play'), findsOneWidget);
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('PLAY'), findsOneWidget);
    });
  });

  group('ARDI-90: LocationManagementScreen Google Maps & Form Verification', () {
    late InMemoryTokenStorage tokenStorage;
    late AuthRepository authRepo;

    setUp(() async {
      tokenStorage = InMemoryTokenStorage();
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'tok-123',
          refreshToken: 'ref-123',
          userId: 99,
          role: 'buyer',
          name: 'Ardi Buyer',
        ),
      );

      final adapter = _TestHttpAdapter((options) async {
        return _TestHttpAdapter.json({
          'success': true,
          'data': {
            'id': 99,
            'email': 'ardi@gmail.com',
            'role': 'buyer',
            'name': 'Ardi Buyer',
            'buyer': {
              'id': 1,
              'business_type': 'resto',
              'address': 'Jl. Kemang Raya No. 18, Jakarta Selatan',
              'base_lat': -6.2615,
              'base_lng': 106.8106,
              'pref_categories': [],
              'max_radius_km': 15,
              'has_cold_storage': false,
              'total_orders_completed': 0,
              'payment_reliability_score': 1.0,
            },
          },
        });
      });

      final client = ApiClient(tokenStorage: tokenStorage, adapter: adapter);
      authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: tokenStorage,
      );
      await authRepo.init();
      await authRepo.fetchProfile();
      AuthRepository.instance = authRepo;
    });

    testWidgets(
      'Renders all Google Maps UI elements, HUD, watermark, and form fields',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: LocationManagementScreen()),
        );
        await tester.pumpAndSettle();

        // Active location card
        expect(
          find.byKey(const Key('current_location_address')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('current_location_coordinates')),
          findsOneWidget,
        );

        // Google Maps canvas, watermark, and pin
        expect(
          find.byKey(const Key('map_interactive_container')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('google_maps_watermark')), findsOneWidget);
        expect(find.byKey(const Key('map_pin_indicator')), findsOneWidget);
        expect(find.byKey(const Key('map_coordinates_hud')), findsOneWidget);

        // Controls
        expect(find.byKey(const Key('btn_zoom_in')), findsOneWidget);
        expect(find.byKey(const Key('btn_zoom_out')), findsOneWidget);
        expect(find.byKey(const Key('btn_my_gps_location')), findsOneWidget);

        // Form inputs
        expect(find.byKey(const Key('input_address')), findsOneWidget);
        expect(find.byKey(const Key('input_city')), findsOneWidget);
        expect(find.byKey(const Key('btn_save_location')), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping preset city chip updates coordinates and address input',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: LocationManagementScreen()),
        );
        await tester.pumpAndSettle();

        final surabayaChip = find.byKey(const Key('city_chip_Surabaya'));
        expect(surabayaChip, findsOneWidget);

        await tester.tap(surabayaChip);
        await tester.pumpAndSettle();

        final addrInput = tester.widget<TextFormField>(
          find.byKey(const Key('input_address')),
        );
        expect(addrInput.controller?.text, contains('Surabaya'));
        expect(find.textContaining('-7.2575'), findsWidgets);
      },
    );

    testWidgets('Map zoom buttons and pan drag gesture update map state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: LocationManagementScreen()),
      );
      await tester.pumpAndSettle();

      // Zoom in
      await tester.tap(find.byKey(const Key('btn_zoom_in')));
      await tester.pumpAndSettle();

      // Zoom out
      await tester.tap(find.byKey(const Key('btn_zoom_out')));
      await tester.pumpAndSettle();

      // Drag / Pan on map
      await tester.drag(
        find.byKey(const Key('map_interactive_container')),
        const Offset(20, -30),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map_coordinates_hud')), findsOneWidget);
    });

    testWidgets(
      'GPS button retrieves GPS coordinates and displays confirmation',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: LocationManagementScreen()),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_my_gps_location')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(const Key('snack_gps_success')), findsOneWidget);
        expect(
          find.text('Lokasi GPS berhasil diperoleh: Jakarta Pusat'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Permission denied simulation displays warning banner and error snackBar',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: LocationManagementScreen()),
        );
        await tester.pumpAndSettle();

        // Toggle permission denial switch
        await tester.tap(find.byKey(const Key('toggle_permission_denial')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('permission_denied_banner')),
          findsOneWidget,
        );

        // Now tap GPS button with permission denied
        await tester.tap(find.byKey(const Key('btn_my_gps_location')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byKey(const Key('snack_permission_denied')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Manual coordinate mode toggle displays numeric latitude and longitude inputs',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: LocationManagementScreen()),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('toggle_map_mode')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('input_latitude')), findsOneWidget);
        expect(find.byKey(const Key('input_longitude')), findsOneWidget);
      },
    );

    testWidgets(
      'Form validation rejects empty address or out-of-range coordinates',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: LocationManagementScreen()),
        );
        await tester.pumpAndSettle();

        // Clear address
        await tester.enterText(find.byKey(const Key('input_address')), '');
        await tester.ensureVisible(find.byKey(const Key('btn_save_location')));
        await tester.tap(find.byKey(const Key('btn_save_location')));
        await tester.pumpAndSettle();

        expect(find.text('Alamat wajib diisi'), findsOneWidget);
      },
    );

    testWidgets(
      'Saving valid location updates profile and triggers success toast',
      (tester) async {
        bool updateApiCalled = false;
        final adapter = _TestHttpAdapter((options) async {
          if (options.method == 'PATCH') {
            updateApiCalled = true;
            return _TestHttpAdapter.json({
              'success': true,
              'data': {
                'id': 99,
                'email': 'ardi@gmail.com',
                'role': 'buyer',
                'name': 'Ardi Buyer',
                'buyer': {
                  'id': 1,
                  'business_type': 'resto',
                  'address': 'Jl. Margonda Raya No. 88, Depok',
                  'base_lat': -6.4025,
                  'base_lng': 106.7942,
                  'pref_categories': [],
                  'max_radius_km': 15,
                  'has_cold_storage': false,
                  'total_orders_completed': 0,
                  'payment_reliability_score': 1.0,
                },
              },
            });
          }
          return _TestHttpAdapter.json({'success': true, 'data': {}});
        });

        final client = ApiClient(tokenStorage: tokenStorage, adapter: adapter);
        final repo = AuthRepository(
          authApiService: AuthApiService(client: client),
          tokenStorage: tokenStorage,
        );
        await repo.init();
        AuthRepository.instance = repo;

        await tester.pumpWidget(
          const MaterialApp(home: LocationManagementScreen()),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('input_address')),
          'Jl. Margonda Raya No. 88, Depok',
        );
        await tester.enterText(find.byKey(const Key('input_city')), 'Depok');

        await tester.ensureVisible(find.byKey(const Key('btn_save_location')));
        await tester.tap(find.byKey(const Key('btn_save_location')));
        await tester.pumpAndSettle();

        expect(updateApiCalled, isTrue);
        expect(
          repo.currentUserProfile?.address,
          'Jl. Margonda Raya No. 88, Depok',
        );
      },
    );
  });

  group('ARDI-90: HomeScreen & MainShell Dynamic Buyer Location Tests', () {
    late InMemoryTokenStorage tokenStorage;
    late AuthRepository authRepo;

    setUp(() async {
      tokenStorage = InMemoryTokenStorage();
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'tok-123',
          refreshToken: 'ref-123',
          userId: 99,
          role: 'buyer',
          name: 'Ardi Buyer',
        ),
      );

      final adapter = _TestHttpAdapter((options) async {
        Map<dynamic, dynamic> data = {};
        if (options.data is Map) {
          data = options.data as Map;
        } else if (options.data is String) {
          try {
            data = jsonDecode(options.data as String) as Map;
          } catch (_) {}
        }
        return _TestHttpAdapter.json({
          'success': true,
          'data': {
            'id': 99,
            'email': 'ardi@gmail.com',
            'role': 'buyer',
            'name': data['name'] ?? 'Ardi Pratama',
            'buyer': {
              'id': 1,
              'business_type': data['business_type'] ?? 'resto',
              'address':
                  data['address'] ?? 'Jl. Pemuda No. 45, Genteng, Surabaya',
              'base_lat': data['base_lat'] ?? -7.2575,
              'base_lng': data['base_lng'] ?? 112.7521,
              'pref_categories': [],
              'max_radius_km': 15,
              'has_cold_storage': false,
              'total_orders_completed': 0,
              'payment_reliability_score': 1.0,
            },
          },
        });
      });

      final client = ApiClient(tokenStorage: tokenStorage, adapter: adapter);
      authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: tokenStorage,
      );
      await authRepo.init();
      AuthRepository.instance = authRepo;
    });

    testWidgets(
      'HomeScreen reflects saved buyer location and passes coordinates to ListingRepository',
      (tester) async {
        // Set initial buyer profile
        authRepo.currentUserProfile = UserProfile(
          id: 99,
          email: 'ardi@gmail.com',
          role: 'buyer',
          name: 'Ardi Pratama',
          address: 'Jl. Pemuda No. 45, Genteng, Surabaya',
          city: 'Surabaya',
          baseLat: -7.2575,
          baseLng: 112.7521,
        );

        final testListingRepo = _TestListingRepo();

        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(repository: testListingRepo)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(const Key('buyer_location_text')), findsOneWidget);
        expect(
          find.text('Jl. Pemuda No. 45, Genteng, Surabaya'),
          findsOneWidget,
        );
        expect(testListingRepo.lastRequestedLat, -7.2575);
        expect(testListingRepo.lastRequestedLng, 112.7521);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'Tapping HomeScreen location bar navigates to LocationManagementScreen',
      (tester) async {
        final testListingRepo = _TestListingRepo();

        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(repository: testListingRepo)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.byKey(const Key('home_location_bar_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('home_location_bar_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('location_management_screen')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'MainShell supplies buyer saved coordinates to HomeScreen adaptively',
      (tester) async {
        authRepo.currentUserProfile = UserProfile(
          id: 99,
          email: 'ardi@gmail.com',
          role: 'buyer',
          name: 'Ardi Pratama',
          address: 'Jl. Malioboro No. 56, Yogyakarta',
          city: 'Yogyakarta',
          baseLat: -7.7956,
          baseLng: 110.3695,
        );

        final testListingRepo = _TestListingRepo();

        await tester.pumpWidget(
          MaterialApp(
            home: MainShell(
              listingRepository: testListingRepo,
              stokPage: const SizedBox.shrink(),
              profilePage: const SizedBox.shrink(),
              feedbackPage: const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byKey(const Key('buyer_location_text')), findsOneWidget);
        expect(find.text('Jl. Malioboro No. 56, Yogyakarta'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
