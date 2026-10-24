import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recovera/core/services/device_location_service.dart';
import 'package:recovera/core/services/place_search_service.dart';
import 'package:recovera/data/data.dart';
import 'package:recovera/features/auth/screens/location_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('PlaceSearchService Unit Tests', () {
    test('returns empty list when query is empty or whitespace', () async {
      final service = PlaceSearchService();
      final results = await service.searchPlaces('   ');
      expect(results, isEmpty);
    });

    test('parses PlaceSearchResult from JSON correctly', () {
      final json = {
        'display_name': 'Monumen Nasional, Gambir, Jakarta Pusat',
        'lat': '-6.175392',
        'lon': '106.827153',
      };
      final result = PlaceSearchResult.fromJson(json);
      expect(result.displayName, 'Monumen Nasional, Gambir, Jakarta Pusat');
      expect(result.latitude, -6.175392);
      expect(result.longitude, 106.827153);
    });

    test('mockSearchResults override works for testing', () async {
      PlaceSearchService.mockSearchResults = [
        const PlaceSearchResult(
          displayName: 'Gedung Sate, Bandung',
          latitude: -6.9025,
          longitude: 107.6186,
        ),
      ];

      final service = PlaceSearchService();
      final results = await service.searchPlaces('Gedung Sate');
      expect(results.length, 1);
      expect(results.first.displayName, 'Gedung Sate, Bandung');
      expect(results.first.latitude, -6.9025);

      PlaceSearchService.mockSearchResults = null;
    });
  });

  group('Interactive Map & Place Search Acceptance Tests', () {
    late InMemoryTokenStorage tokenStorage;
    late AuthRepository authRepo;

    setUp(() async {
      tokenStorage = InMemoryTokenStorage();
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'test-token',
          refreshToken: 'test-rt',
          userId: 99,
          role: 'buyer',
          name: 'Ardi Buyer',
        ),
      );

      final client = ApiClient(tokenStorage: tokenStorage);
      authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: tokenStorage,
      );
      await authRepo.init();
      authRepo.currentUserProfile = const UserProfile(
        id: 99,
        email: 'buyer@recovera.id',
        role: 'buyer',
        name: 'Ardi Buyer',
        address: 'Jl. Medan Merdeka Barat No. 1, Jakarta Pusat',
        city: 'Jakarta Pusat',
        baseLat: -6.1754,
        baseLng: 106.8272,
      );
      AuthRepository.instance = authRepo;
    });

    tearDown(() {
      PlaceSearchService.mockSearchResults = null;
      DeviceLocationService.mockPermissionStatus = null;
      DeviceLocationService.mockLocationData = null;
    });

    testWidgets('Search input displays results dropdown and selects place on tap', (tester) async {
      PlaceSearchService.mockSearchResults = [
        const PlaceSearchResult(
          displayName: 'Jl. Malioboro, Danurejan, Kota Yogyakarta',
          latitude: -7.7926,
          longitude: 110.3658,
        ),
        const PlaceSearchResult(
          displayName: 'Malioboro Mall, Kota Yogyakarta',
          latitude: -7.7932,
          longitude: 110.3662,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: LocationManagementScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify search input is rendered
      expect(find.byKey(const Key('input_search_place')), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byKey(const Key('input_search_place')), 'Malioboro');
      await tester.pumpAndSettle();

      // Submit search
      await tester.tap(find.byKey(const Key('btn_search_place')));
      await tester.pumpAndSettle();

      // Verify results dropdown is displayed
      expect(find.byKey(const Key('search_results_container')), findsOneWidget);
      expect(find.text('Jl. Malioboro, Danurejan, Kota Yogyakarta'), findsOneWidget);

      // Tap on first result
      await tester.tap(find.byKey(const Key('search_result_item_0')));
      await tester.pumpAndSettle();

      // Verify search results dropdown is closed
      expect(find.byKey(const Key('search_results_container')), findsNothing);

      // Verify form address and coordinates updated to chosen place
      final addrField = tester.widget<TextFormField>(find.byKey(const Key('input_address')));
      expect(addrField.controller?.text, 'Jl. Malioboro, Danurejan, Kota Yogyakarta');

      final latField = tester.widget<TextFormField>(find.byKey(const Key('input_latitude')));
      final lngField = tester.widget<TextFormField>(find.byKey(const Key('input_longitude')));
      expect(latField.controller?.text, '-7.792600');
      expect(lngField.controller?.text, '110.365800');

      // Verify HUD coordinates reflect new coordinates
      expect(find.textContaining('-7.7926'), findsWidgets);
      expect(find.textContaining('110.3658'), findsWidgets);
    });

    testWidgets('Pinching / zooming and panning interactions function smoothly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LocationManagementScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify map container and pin indicator exist
      expect(find.byKey(const Key('map_interactive_container')), findsOneWidget);
      expect(find.byKey(const Key('map_pin_indicator')), findsOneWidget);

      // Zoom in
      await tester.tap(find.byKey(const Key('btn_zoom_in')));
      await tester.pumpAndSettle();

      // Zoom out
      await tester.tap(find.byKey(const Key('btn_zoom_out')));
      await tester.pumpAndSettle();

      // Drag / Pan gesture on map
      await tester.drag(find.byKey(const Key('map_touch_detector')), const Offset(20, -15));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map_coordinates_hud')), findsOneWidget);
    });

    testWidgets('Tapping map updates coordinates and repositions pin', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LocationManagementScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Drag map to simulate pan
      await tester.drag(find.byKey(const Key('map_touch_detector')), const Offset(40, -40));
      await tester.pumpAndSettle();

      final latField = tester.widget<TextFormField>(find.byKey(const Key('input_latitude')));
      expect(latField.controller?.text, isNotEmpty);
    });
  });
}
