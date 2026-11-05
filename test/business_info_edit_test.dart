import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/storage/token_storage.dart';
import 'package:recovera/data/repositories/auth_repository.dart';
import 'package:recovera/data/services/auth_api_service.dart';
import 'package:recovera/features/auth/models/user_profile.dart';
import 'package:recovera/features/auth/screens/business_info_edit_screen.dart';

class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter(this.handler);

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

void main() {
  late InMemoryTokenStorage tokenStorage;
  late _MockHttpAdapter adapter;
  late AuthRepository repo;
  Map<String, dynamic>? lastPatchBody;

  setUp(() async {
    tokenStorage = InMemoryTokenStorage();
    await tokenStorage.saveTokens(
      const AuthTokens(
        accessToken: 'mock_token',
        refreshToken: 'mock_refresh',
        userId: 1,
        role: 'buyer',
        name: 'Gevinta Aprilia',
      ),
    );

    adapter = _MockHttpAdapter((options) async {
      if (options.method == 'PATCH' && options.path.contains('/profile')) {
        lastPatchBody = options.data is Map<String, dynamic>
            ? options.data as Map<String, dynamic>
            : jsonDecode(options.data.toString()) as Map<String, dynamic>;

        return _MockHttpAdapter.json({
          'id': 1,
          'email': 'user@recovera.dev',
          'role': lastPatchBody?['role'] ?? 'buyer',
          'name': lastPatchBody?['name'] ?? 'Gevinta Aprilia',
          'phone': lastPatchBody?['phone'] ?? '081234567890',
          'company_name': lastPatchBody?['company_name'],
          'business_type': lastPatchBody?['business_type'] ?? 'resto',
          'address': lastPatchBody?['address'] ?? 'Jl. Pemuda No. 10',
          'city': lastPatchBody?['city'] ?? 'Surabaya',
          'base_lat': lastPatchBody?['base_lat'] ?? -7.2575,
          'base_lng': lastPatchBody?['base_lng'] ?? 112.7521,
          'warehouse_lat': lastPatchBody?['warehouse_lat'],
          'warehouse_lng': lastPatchBody?['warehouse_lng'],
          'pref_categories': lastPatchBody?['pref_categories'] ?? ['Beverage'],
          'max_radius_km': lastPatchBody?['max_radius_km'] ?? 15,
          'has_cold_storage': lastPatchBody?['has_cold_storage'] ?? false,
        });
      }
      return _MockHttpAdapter.json({});
    });

    final client = ApiClient(tokenStorage: tokenStorage, adapter: adapter);
    repo = AuthRepository(
      authApiService: AuthApiService(client: client),
      tokenStorage: tokenStorage,
    );
    await repo.init();
    AuthRepository.instance = repo;
  });

  group('BusinessInfoEditScreen Widget & Integration Tests', () {
    testWidgets('Renders all Buyer fields correctly with initial values', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      repo.currentUserProfile = const UserProfile(
        id: 1,
        email: 'gevinta@recovera.dev',
        role: 'buyer',
        name: 'Gevinta Aprilia',
        phone: '081234567890',
        businessType: 'resto',
        address: 'Jl. Pemuda No. 10',
        city: 'Surabaya',
        baseLat: -7.2575,
        baseLng: 112.7521,
        prefCategories: ['Beverage', 'Dairy'],
        maxRadiusKm: 12,
        hasColdStorage: true,
      );

      await tester.pumpWidget(
        const MaterialApp(home: BusinessInfoEditScreen()),
      );
      await tester.pumpAndSettle();

      // Header title & subtitle
      expect(find.text('Informasi Bisnis'), findsOneWidget);
      expect(find.text('Kelola Profil Usaha & Pengadaan'), findsOneWidget);

      // Section 1: PIC
      expect(find.byKey(const Key('input_pic_name')), findsOneWidget);
      expect(find.text('Gevinta Aprilia'), findsOneWidget);
      expect(find.byKey(const Key('input_phone')), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);

      // Section 2: Business Profile (Dropdown for buyer)
      expect(find.byKey(const Key('dropdown_business_type')), findsOneWidget);
      expect(find.text('Restoran / Rumah Makan'), findsOneWidget);

      // Section 3: Location
      expect(find.byKey(const Key('btn_open_map_picker')), findsOneWidget);
      expect(find.byKey(const Key('input_address')), findsOneWidget);
      expect(find.text('Jl. Pemuda No. 10'), findsOneWidget);
      expect(find.byKey(const Key('display_coordinates')), findsOneWidget);
      expect(find.textContaining('-7.2575'), findsWidgets);

      // Buyer should NOT see seller city input
      expect(find.byKey(const Key('input_city')), findsNothing);

      // Section 4: Buyer Preferences
      expect(find.byKey(const Key('chip_category_Beverage')), findsOneWidget);
      expect(find.byKey(const Key('chip_category_Canned')), findsOneWidget);
      expect(find.byKey(const Key('chip_category_Dairy')), findsOneWidget);
      expect(
        find.byKey(const Key('chip_category_Flour & Grain')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chip_category_Frozen')), findsOneWidget);
      expect(find.byKey(const Key('chip_category_Oil')), findsOneWidget);
      expect(find.text('2 Dipilih'), findsOneWidget);

      // Slider & cold storage switch
      expect(find.byKey(const Key('slider_radius')), findsOneWidget);
      expect(find.text('12 km'), findsOneWidget);
      expect(find.byKey(const Key('switch_cold_storage')), findsOneWidget);

      // Save button
      expect(find.byKey(const Key('btn_save_business_info')), findsOneWidget);
    });

    testWidgets('Renders all Seller fields correctly and excludes buyer preferences', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'mock_token',
          refreshToken: 'mock_refresh',
          userId: 2,
          role: 'seller',
          name: 'Budi Santoso',
        ),
      );
      await repo.init();

      repo.currentUserProfile = const UserProfile(
        id: 2,
        email: 'budi@distributor.com',
        role: 'seller',
        name: 'Budi Santoso',
        phone: '081398765432',
        companyName: 'PT Sumber Pangan Makmur',
        address: 'Jl. Rungkut Industri No. 4',
        city: 'Surabaya',
        warehouseLat: -7.3214,
        warehouseLng: 112.7689,
      );

      await tester.pumpWidget(
        const MaterialApp(home: BusinessInfoEditScreen()),
      );
      await tester.pumpAndSettle();

      // Header subtitle for seller
      expect(
        find.text('Kelola Profil Distributor & Gudang'),
        findsOneWidget,
      );

      // PIC
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('081398765432'), findsOneWidget);

      // Seller company name TextField
      expect(find.byKey(const Key('input_company_name')), findsOneWidget);
      expect(find.text('PT Sumber Pangan Makmur'), findsOneWidget);

      // Dropdown business type should NOT exist for seller
      expect(find.byKey(const Key('dropdown_business_type')), findsNothing);

      // Location fields: address and city exist
      expect(find.byKey(const Key('input_address')), findsOneWidget);
      expect(find.text('Jl. Rungkut Industri No. 4'), findsOneWidget);
      expect(find.byKey(const Key('input_city')), findsOneWidget);
      expect(find.text('Surabaya'), findsOneWidget);
      expect(find.textContaining('-7.3214'), findsWidgets);

      // Buyer preferences should NOT exist for seller
      expect(find.byKey(const Key('chip_category_Beverage')), findsNothing);
      expect(find.byKey(const Key('slider_radius')), findsNothing);
      expect(find.byKey(const Key('switch_cold_storage')), findsNothing);
    });

    testWidgets('Toggling category chips updates selected count', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      repo.currentUserProfile = const UserProfile(
        id: 1,
        email: 'buyer@test.com',
        role: 'buyer',
        name: 'Buyer Test',
        prefCategories: ['Beverage'],
      );

      await tester.pumpWidget(
        const MaterialApp(home: BusinessInfoEditScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 Dipilih'), findsOneWidget);

      // Tap 'Canned' chip to add
      await tester.tap(find.byKey(const Key('chip_category_Canned')));
      await tester.pumpAndSettle();
      expect(find.text('2 Dipilih'), findsOneWidget);

      // Tap 'Beverage' chip to deselect
      await tester.tap(find.byKey(const Key('chip_category_Beverage')));
      await tester.pumpAndSettle();
      expect(find.text('1 Dipilih'), findsOneWidget);
    });

    testWidgets('Saving updates profile and calls API with form values', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      repo.currentUserProfile = const UserProfile(
        id: 1,
        email: 'buyer@test.com',
        role: 'buyer',
        name: 'Gevinta A',
        phone: '081234567890',
        businessType: 'resto',
        address: 'Jl. Merak No. 5',
        baseLat: -6.2088,
        baseLng: 106.8456,
        prefCategories: ['Beverage'],
      );

      await tester.pumpWidget(
        const MaterialApp(home: BusinessInfoEditScreen()),
      );
      await tester.pumpAndSettle();

      // Tap save button
      await tester.tap(find.byKey(const Key('btn_save_business_info')));
      await tester.pumpAndSettle();

      // Check lastPatchBody was called with correct values
      expect(lastPatchBody, isNotNull);
      expect(lastPatchBody!['name'], 'Gevinta A');
      expect(lastPatchBody!['phone'], '081234567890');
      expect(lastPatchBody!['business_type'], 'resto');
      expect(lastPatchBody!['address'], 'Jl. Merak No. 5');
    });
  });
}
