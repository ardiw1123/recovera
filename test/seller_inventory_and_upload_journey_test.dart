import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/core/navigation/app_navigator.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/storage/token_storage.dart';
import 'package:recovera/data/repositories/auth_repository.dart';
import 'package:recovera/data/services/auth_api_service.dart';
import 'package:recovera/features/seller/models/seller_inventory_model.dart';
import 'package:recovera/features/seller/repositories/seller_repository.dart';
import 'package:recovera/features/seller/screens/seller_inventory_screen.dart';
import 'package:recovera/features/seller/screens/upload_stock_flow_screen.dart';
import 'package:recovera/features/seller/services/seller_api_service.dart';
import 'package:recovera/features/shell/main_shell.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Seller Inventory Models & Formatting Tests', () {
    test('formatCurrency formats Rupiah with dots correctly', () {
      expect(formatCurrency(0), 'Rp0');
      expect(formatCurrency(15000), 'Rp15.000');
      expect(formatCurrency(1500000), 'Rp1.500.000');
      expect(formatCurrency(9000.5), 'Rp9.001');
    });

    test('SellerListingItem parses full JSON and computed getters', () {
      final json = {
        'id': 12,
        'product_id': 101,
        'seller_id': 5,
        'batch_number': 'LOT-2026-X1',
        'qty': 500,
        'normal_price': 15000.0,
        'start_price': 12000.0,
        'min_price': 7000.0,
        'current_price': 9000.0,
        'expiry_date': '2026-06-30T00:00:00Z',
        'status': 'active',
        'created_at': '2026-04-01T10:00:00Z',
        'product': {
          'id': 101,
          'name': 'Susu UHT Fresh 1L',
          'category': 'Produk Olahan Susu & Dairy',
          'image_url': 'https://example.com/susu.jpg',
          'default_unit': 'box',
          'description': 'Susu sapi murni segar',
        },
      };

      final item = SellerListingItem.fromJson(json);
      expect(item.id, 12);
      expect(item.productName, 'Susu UHT Fresh 1L');
      expect(item.defaultUnit, 'box');
      expect(item.category, 'Produk Olahan Susu & Dairy');
      expect(item.qty, 500);
      expect(item.normalPrice, 15000.0);
      expect(item.currentPrice, 9000.0);
      expect(item.batchNumber, 'LOT-2026-X1');
      expect(item.status, 'active');
      expect(item.isPublished, isTrue);
      expect(item.discountPercentage, closeTo(40.0, 0.1));
      expect(item.displayStatusLabel, isNotEmpty);
      expect(item.daysRemainingText, contains('hari tersisa'));

      final serialized = item.toJson();
      expect(serialized['id'], 12);
      expect(serialized['qty'], 500);
    });

    test('SellerValidationResult parses JSON correctly', () {
      final json = {
        'valid': true,
        'errors': <String>[],
        'status': 'review',
      };

      final result = SellerValidationResult.fromJson(json);
      expect(result.isValid, isTrue);
      expect(result.status, 'review');
      expect(result.errors.isEmpty, isTrue);
    });

    test('SellerRecommendationResult parses advice correctly', () {
      final json = {
        'recommendation': {
          'suggested_price': 9000.0,
          'discount_pct': 40.0,
          'rationale': 'Berdasarkan kecepatan penjualan batch susu serupa.',
          'next_drop_at': '2026-04-02T10:00:00Z',
        },
        'price_warning': false,
        'accepted_range': {
          'minimum': 7200.0,
          'maximum': 10800.0,
        },
      };

      final rec = SellerRecommendationResult.fromJson(json);
      expect(rec.suggestedPrice, 9000.0);
      expect(rec.discountPct, 40.0);
      expect(rec.rationale, 'Berdasarkan kecepatan penjualan batch susu serupa.');
      expect(rec.hasPriceWarning, isFalse);
      expect(rec.minAcceptedPrice, 7200.0);
      expect(rec.maxAcceptedPrice, 10800.0);
    });

    test('SellerDraftCreatePayload serializes correctly', () {
      const payload = SellerDraftCreatePayload(
        sku: 'SKU-TP-1',
        name: 'Tepung Segitiga 1kg',
        category: 'Bahan Pokok & Sembako',
        storageType: 'ambient',
        defaultUnit: 'kg',
        imageUrl: 'https://example.com/tepung.jpg',
        batchNumber: 'LOT-2026-TP1',
        qty: 200,
        normalPrice: 14000.0,
        minPrice: 7000.0,
        expiryDate: '2026-08-01',
      );

      final map = payload.toJson();
      expect(map['sku'], 'SKU-TP-1');
      expect(map['name'], 'Tepung Segitiga 1kg');
      expect(map['category'], 'Bahan Pokok & Sembako');
      expect(map['qty'], 200);
      expect(map['normal_price'], 14000.0);
      expect(map['min_price'], 7000.0);
      expect(map['expiry_date'], '2026-08-01');
    });
  });

  group('Seller API Service with Mocked Backend Tests', () {
    late InMemoryTokenStorage storage;

    setUp(() {
      storage = InMemoryTokenStorage();
    });

    test('fetchSellerInventory returns list of listings', () async {
      final adapter = TestMockAdapter((options) async {
        if (options.path.contains('/listings/seller/inventory')) {
          return TestMockAdapter.json({
            'success': true,
            'data': [
              {
                'id': 1,
                'product_id': 10,
                'batch_number': 'LOT-1',
                'qty': 100,
                'normal_price': 10000.0,
                'start_price': 8000.0,
                'min_price': 5000.0,
                'current_price': 7500.0,
                'expiry_date': '2026-05-01T00:00:00Z',
                'status': 'active',
                'product': {
                  'id': 10,
                  'name': 'Roti Gandum Sehat',
                  'category': 'Roti & Bakery',
                  'default_unit': 'pcs',
                },
              }
            ]
          });
        }
        return TestMockAdapter.json({}, statusCode: 404);
      });

      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      final service = SellerApiService(client: client);

      final items = await service.fetchSellerInventory();
      expect(items.length, 1);
      expect(items.first.productName, 'Roti Gandum Sehat');
      expect(items.first.qty, 100);
    });

    test('createDraft posts correct payload and returns new item with validation', () async {
      final adapter = TestMockAdapter((options) async {
        if (options.path.contains('/listings/seller/inventory/drafts') &&
            options.method == 'POST') {
          final data = options.data as Map<String, dynamic>;
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'listing': {
                'id': 99,
                'product_id': 200,
                'batch_number': data['batch_number'],
                'qty': data['qty'],
                'normal_price': data['normal_price'],
                'start_price': data['normal_price'] * 0.8,
                'min_price': data['min_price'],
                'current_price': data['normal_price'] * 0.8,
                'expiry_date': data['expiry_date'],
                'status': 'draft',
                'product': {
                  'id': 200,
                  'name': data['name'],
                  'category': data['category'],
                  'default_unit': data['default_unit'],
                },
              },
              'validation': {
                'valid': true,
                'errors': <String>[],
                'status': 'draft',
              },
              'price_recommendation': {
                'recommendation': {
                  'suggested_price': 14000.0,
                  'discount_pct': 30.0,
                  'rationale': 'Rekomendasi sistem',
                  'next_drop_at': '2026-05-16T00:00:00Z',
                },
                'price_warning': false,
                'accepted_range': {'minimum': 11200.0, 'maximum': 16800.0},
              },
            }
          }, statusCode: 201);
        }
        return TestMockAdapter.json({}, statusCode: 400);
      });

      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      final service = SellerApiService(client: client);

      const payload = SellerDraftCreatePayload(
        sku: 'SKU-YOG-01',
        name: 'Yogurt Strawberry 500ml',
        category: 'Produk Olahan Susu & Dairy',
        defaultUnit: 'botol',
        imageUrl: 'https://example.com/yogurt.jpg',
        batchNumber: 'LOT-YOG-01',
        qty: 50,
        normalPrice: 20000.0,
        minPrice: 10000.0,
        expiryDate: '2026-05-15',
      );

      final result = await service.createDraft(payload);
      final created = result['listing'] as SellerListingItem;
      expect(created.id, 99);
      expect(created.productName, 'Yogurt Strawberry 500ml');
      expect(created.status, 'draft');
    });

    test('validateDraft posts to validate endpoint', () async {
      final adapter = TestMockAdapter((options) async {
        if (options.path.contains('/listings/seller/inventory/99/validate') &&
            options.method == 'POST') {
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'valid': true,
              'errors': <String>[],
              'status': 'review',
            }
          });
        }
        return TestMockAdapter.json({}, statusCode: 400);
      });

      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      final service = SellerApiService(client: client);

      final val = await service.validateDraft(99);
      expect(val.isValid, isTrue);
      expect(val.status, 'review');
    });

    test('getPriceRecommendation posts to recommendation endpoint', () async {
      final adapter = TestMockAdapter((options) async {
        if (options.path.contains('/listings/seller/inventory/99/recommendation') &&
            options.method == 'POST') {
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'recommendation': {
                'suggested_price': 13500.0,
                'discount_pct': 32.5,
                'rationale': 'Rekomendasi diskon optimal',
                'next_drop_at': '2026-05-16T00:00:00Z',
              },
              'price_warning': false,
              'accepted_range': {'minimum': 10800.0, 'maximum': 16200.0},
            }
          });
        }
        return TestMockAdapter.json({}, statusCode: 400);
      });

      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      final service = SellerApiService(client: client);

      final rec = await service.getPriceRecommendation(99);
      expect(rec.suggestedPrice, 13500.0);
      expect(rec.minAcceptedPrice, 10800.0);
    });

    test('publishListing completes publication', () async {
      final adapter = TestMockAdapter((options) async {
        if (options.path.contains('/listings/seller/inventory/99/publish') &&
            options.method == 'POST') {
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'id': 99,
              'product_id': 200,
              'batch_number': 'LOT-YOG-01',
              'qty': 50,
              'normal_price': 20000.0,
              'start_price': 16000.0,
              'min_price': 10000.0,
              'current_price': 13500.0,
              'expiry_date': '2026-05-15T00:00:00Z',
              'status': 'active',
              'product': {
                'id': 200,
                'name': 'Yogurt Strawberry 500ml',
                'category': 'Produk Olahan Susu & Dairy',
                'default_unit': 'botol',
              },
            }
          });
        }
        return TestMockAdapter.json({}, statusCode: 400);
      });

      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      final service = SellerApiService(client: client);

      final published = await service.publishListing(99);
      expect(published.isPublished, isTrue);
      expect(published.status, 'active');
    });
  });

  group('Seller Repository Tests', () {
    test('loadInventory populates items and activeCount correctly', () async {
      final storage = InMemoryTokenStorage();
      final mockData = [
        {
          'id': 1,
          'product_id': 10,
          'batch_number': 'LOT-A',
          'qty': 50,
          'normal_price': 10000.0,
          'start_price': 8000.0,
          'min_price': 5000.0,
          'current_price': 7000.0,
          'expiry_date': '2026-05-01T00:00:00Z',
          'status': 'active',
          'product': {'name': 'Apel Fuji', 'category': 'Buah & Sayur', 'default_unit': 'kg'},
        },
      ];

      final adapter = TestMockAdapter((options) async {
        return TestMockAdapter.json({'success': true, 'data': mockData});
      });

      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      final repo = SellerRepository(apiService: SellerApiService(client: client));
      await repo.loadInventory();

      expect(repo.items.length, 1);
      expect(repo.items.first.productName, 'Apel Fuji');
      expect(repo.totalCount, 1);
      expect(repo.activeCount, 1);
    });
  });

  group('Role Isolation & Guard Tests', () {
    late InMemoryTokenStorage storage;
    late AuthRepository authRepo;

    setUp(() {
      storage = InMemoryTokenStorage();
      final client = ApiClient(tokenStorage: storage);
      authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
      AuthRepository.instance = authRepo;
    });

    test('isSeller is true only when user role is seller', () async {
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'seller-token',
          refreshToken: 'seller-refresh',
          userId: 101,
          role: 'seller',
        ),
      );
      await authRepo.init();

      expect(authRepo.currentUserRole, 'seller');
      expect(authRepo.isSeller, isTrue);
      expect(authRepo.isBuyer, isFalse);

      // Verify AppNavigator guard allows seller
      expect(AppNavigator.verifySellerAccess(), isTrue);
    });

    test('isBuyer denies seller access and route verification returns false', () async {
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'buyer-token',
          refreshToken: 'buyer-refresh',
          userId: 102,
          role: 'buyer',
        ),
      );
      await authRepo.init();

      expect(authRepo.currentUserRole, 'buyer');
      expect(authRepo.isSeller, isFalse);
      expect(authRepo.isBuyer, isTrue);

      // Buyer MUST be denied access to seller journeys
      expect(AppNavigator.verifySellerAccess(), isFalse);
    });

    testWidgets('MainShell renders Stok Saya and Tambah only for Seller role',
        (tester) async {
      // 1. Seller Session
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'seller-token',
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

      // Seller bottom nav should have "Beranda", "Stok", and "Tambah"
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.byKey(const Key('nav_seller_add_stock')), findsOneWidget);
      expect(find.text('Tambah'), findsOneWidget);

      // 2. Switch to Buyer Session
      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'buyer-token',
          refreshToken: 'buyer-refresh',
          userId: 102,
          role: 'buyer',
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

      // Buyer should NOT see Tambah upload button in bottom navigation
      expect(find.byKey(const Key('nav_seller_add_stock')), findsNothing);
      expect(find.text('Tambah'), findsNothing);
      // Buyer should see standard consumer tab Home
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('SellerInventoryScreen Widget Tests', () {
    late SellerRepository mockRepo;

    setUp(() {
      final storage = InMemoryTokenStorage();
      final mockData = [
        {
          'id': 1,
          'product_id': 101,
          'batch_number': 'LOT-2026-X1',
          'qty': 500,
          'normal_price': 15000.0,
          'start_price': 12000.0,
          'min_price': 7000.0,
          'current_price': 9000.0,
          'expiry_date': '2026-06-30T00:00:00Z',
          'status': 'active',
          'product': {
            'id': 101,
            'name': 'Susu UHT Fresh 1L',
            'category': 'Produk Olahan Susu & Dairy',
            'default_unit': 'box',
          },
        },
        {
          'id': 2,
          'product_id': 102,
          'batch_number': 'LOT-2026-R2',
          'qty': 120,
          'normal_price': 22000.0,
          'start_price': 18000.0,
          'min_price': 12000.0,
          'current_price': 15000.0,
          'expiry_date': '2026-05-10T00:00:00Z',
          'status': 'active',
          'product': {
            'id': 102,
            'name': 'Keju Cheddar Olahan 250g',
            'category': 'Produk Olahan Susu & Dairy',
            'default_unit': 'pack',
          },
        },
      ];

      final adapter = TestMockAdapter((options) async {
        return TestMockAdapter.json({'success': true, 'data': mockData});
      });

      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      mockRepo = SellerRepository(apiService: SellerApiService(client: client));
    });

    testWidgets('Renders Stok Saya header, counter badge, and items',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SellerInventoryScreen(repository: mockRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Top title
      expect(find.byKey(const Key('seller_inventory_title')), findsOneWidget);
      // Counter badge shows 2 stok aktif
      expect(find.byKey(const Key('seller_inventory_active_badge')), findsOneWidget);
      expect(find.text('2 stok aktif'), findsOneWidget);

      // Search bar
      expect(find.byType(TextField), findsOneWidget);

      // Tab chips
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Terjual'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);

      // Product cards
      expect(find.text('Susu UHT Fresh 1L'), findsOneWidget);
      expect(find.text('Keju Cheddar Olahan 250g'), findsOneWidget);
    });

    testWidgets('Search query filters items and displays empty state on no match',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SellerInventoryScreen(repository: mockRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Susu UHT Fresh 1L'), findsOneWidget);
      expect(find.text('Keju Cheddar Olahan 250g'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Keju');
      await tester.pump();

      expect(find.text('Keju Cheddar Olahan 250g'), findsOneWidget);
      expect(find.text('Susu UHT Fresh 1L'), findsNothing);

      // Enter query with no results
      await tester.enterText(find.byType(TextField), 'TidakAdaProdukIni');
      await tester.pump();

      expect(find.text('Belum Ada Stok lelang'), findsOneWidget);
    });

    testWidgets('Switching tabs to Terjual updates list view to empty state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SellerInventoryScreen(repository: mockRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap 'Terjual' filter chip
      await tester.tap(find.text('Terjual'));
      await tester.pump();

      // Should show empty state since both items are active
      expect(find.text('Belum Ada Stok lelang'), findsOneWidget);
    });
  });

  group('UploadStockFlowScreen 4-Step Journey Widget Tests', () {
    late SellerRepository mockRepo;

    setUp(() async {
      final storage = InMemoryTokenStorage();
      final adapter = TestMockAdapter((options) async {
        if (options.path.contains('/listings/seller/inventory/drafts')) {
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'listing': {
                'id': 77,
                'product_id': 101,
                'batch_number': 'LOT-2026-X1',
                'qty': 500,
                'normal_price': 15000.0,
                'start_price': 12000.0,
                'min_price': 7000.0,
                'current_price': 9000.0,
                'expiry_date': '2026-06-30T00:00:00Z',
                'status': 'draft',
                'product': {
                  'id': 101,
                  'name': 'Susu UHT Fresh 1L',
                  'category': 'Produk Olahan Susu & Dairy',
                  'default_unit': 'box',
                },
              },
              'validation': {
                'valid': true,
                'errors': <String>[],
                'status': 'draft',
              },
              'price_recommendation': {
                'recommendation': {
                  'suggested_price': 9000.0,
                  'discount_pct': 40.0,
                  'rationale': 'Berdasarkan kecepatan penjualan batch susu serupa.',
                  'next_drop_at': '2026-04-02T10:00:00Z',
                },
                'price_warning': false,
                'accepted_range': {'minimum': 7200.0, 'maximum': 10800.0},
              },
            }
          });
        }
        if (options.path.contains('/validate')) {
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'valid': true,
              'errors': <String>[],
              'status': 'review',
            }
          });
        }
        if (options.path.contains('/recommendation')) {
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'recommendation': {
                'suggested_price': 9000.0,
                'discount_pct': 40.0,
                'rationale': 'Berdasarkan kecepatan penjualan batch susu serupa.',
                'next_drop_at': '2026-04-02T10:00:00Z',
              },
              'price_warning': false,
              'accepted_range': {'minimum': 7200.0, 'maximum': 10800.0},
            }
          });
        }
        if (options.path.contains('/publish')) {
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'id': 77,
              'product_id': 101,
              'batch_number': 'LOT-2026-X1',
              'qty': 500,
              'normal_price': 15000.0,
              'start_price': 12000.0,
              'min_price': 7000.0,
              'current_price': 9000.0,
              'expiry_date': '2026-06-30T00:00:00Z',
              'status': 'active',
              'product': {
                'id': 101,
                'name': 'Susu UHT Fresh 1L',
                'category': 'Produk Olahan Susu & Dairy',
                'default_unit': 'box',
              },
            }
          });
        }
        return TestMockAdapter.json({}, statusCode: 400);
      });

      final client = ApiClient(tokenStorage: storage, adapter: adapter);
      mockRepo = SellerRepository(apiService: SellerApiService(client: client));

      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'seller-token',
          refreshToken: 'seller-refresh',
          userId: 101,
          role: 'seller',
        ),
      );
      final authRepo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
      await authRepo.init();
      AuthRepository.instance = authRepo;
    });

    testWidgets('Step 1 renders form fields and validates correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(repository: mockRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Title & step indicators
      expect(find.byKey(const Key('upload_flow_title')), findsOneWidget);
      expect(find.text('Produk'), findsOneWidget);
      expect(find.text('Validasi'), findsOneWidget);
      expect(find.text('Harga'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);

      // Form fields present
      expect(find.text('Nama Produk'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);
      expect(find.text('Harga Normal'), findsOneWidget);

      // Next button
      expect(find.byKey(const Key('btn_submit_step1')), findsOneWidget);
    });

    testWidgets('Step 1 -> Step 2 -> Step 3 -> Step 4 full flow executes',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(repository: mockRepo),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap 'Lanjut ke Validasi'
      await tester.ensureVisible(find.byKey(const Key('btn_submit_step1')));
      await tester.tap(find.byKey(const Key('btn_submit_step1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Step 2 view: Validasi Mutu
      expect(find.text('Memeriksa Produk'), findsOneWidget);
      expect(find.text('Kriteria Validasi Pangan'), findsOneWidget);

      // Advance timers for simulated validation progress
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Step 2 finishes -> shows completion button
      expect(find.byKey(const Key('btn_proceed_to_pricing')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('btn_proceed_to_pricing')));
      await tester.tap(find.byKey(const Key('btn_proceed_to_pricing')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Step 3: Rekomendasi Cerdas Harga
      expect(find.text('Rekomendasi Cerdas'), findsOneWidget);
      expect(find.text('Harga Rekomendasi'), findsOneWidget);
      expect(find.byKey(const Key('btn_use_recommendation')), findsOneWidget);

      // Tap 'Gunakan Rekomendasi' to advance to Step 4
      await tester.ensureVisible(find.byKey(const Key('btn_use_recommendation')));
      await tester.tap(find.byKey(const Key('btn_use_recommendation')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Step 4: Review & Publish screen
      expect(find.text('Review & Publish'), findsWidgets);
      expect(find.text('Ringkasan Produk'), findsOneWidget);
      expect(find.text('Rincian Harga & Recovery'), findsOneWidget);
      expect(find.byKey(const Key('btn_publish_stock')), findsOneWidget);

      // Tap Publish
      await tester.ensureVisible(find.byKey(const Key('btn_publish_stock')));
      await tester.tap(find.byKey(const Key('btn_publish_stock')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify success dialog
      expect(find.text('Sukses Dipublikasi!'), findsOneWidget);
    });
  });
}
