import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/data/data.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARDI-72 Registration Journey & Role-Specific Contract Alignment', () {
    late InMemoryTokenStorage storage;

    setUp(() {
      storage = InMemoryTokenStorage();
    });

    test('Seller registration transmits required company_name and display name',
        () async {
      Map<String, dynamic>? capturedPayload;
      final adapter = TestMockAdapter((options) async {
        if (options.path.contains(ApiConstants.registerEndpoint)) {
          capturedPayload = options.data as Map<String, dynamic>;
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'access_token': 'seller-access-token',
              'refresh_token': 'seller-refresh-token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user_id': 101,
              'role': 'seller',
              'name': 'PT Pangan Mandiri',
            },
          }, statusCode: 201);
        }
        return TestMockAdapter.json({'success': false}, statusCode: 404);
      });

      final client = ApiClient(
        baseUrl: 'http://test.api',
        tokenStorage: storage,
        adapter: adapter,
      );
      final authService = AuthApiService(client: client);

      final tokens = await authService.register(
        email: 'seller@pangan.com',
        password: 'password123',
        role: 'seller',
        name: 'Budi Santoso',
        companyName: 'PT Pangan Mandiri',
      );

      expect(tokens.accessToken, 'seller-access-token');
      expect(tokens.role, 'seller');
      expect(capturedPayload, isNotNull);
      expect(capturedPayload!['role'], 'seller');
      expect(capturedPayload!['name'], 'Budi Santoso');
      expect(capturedPayload!['company_name'], 'PT Pangan Mandiri');
      expect(capturedPayload!['email'], 'seller@pangan.com');
      expect(capturedPayload!['password'], 'password123');
    });

    test('Buyer registration transmits name without requiring company_name',
        () async {
      Map<String, dynamic>? capturedPayload;
      final adapter = TestMockAdapter((options) async {
        if (options.path.contains(ApiConstants.registerEndpoint)) {
          capturedPayload = options.data as Map<String, dynamic>;
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'access_token': 'buyer-access-token',
              'refresh_token': 'buyer-refresh-token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user_id': 202,
              'role': 'buyer',
              'name': 'Warung Berkah',
            },
          }, statusCode: 201);
        }
        return TestMockAdapter.json({'success': false}, statusCode: 404);
      });

      final client = ApiClient(
        baseUrl: 'http://test.api',
        tokenStorage: storage,
        adapter: adapter,
      );
      final authService = AuthApiService(client: client);

      final tokens = await authService.register(
        email: 'buyer@warung.com',
        password: 'password123',
        role: 'buyer',
        name: 'Siti Rahma',
      );

      expect(tokens.accessToken, 'buyer-access-token');
      expect(tokens.role, 'buyer');
      expect(capturedPayload, isNotNull);
      expect(capturedPayload!['role'], 'buyer');
      expect(capturedPayload!['name'], 'Siti Rahma');
      expect(capturedPayload!.containsKey('company_name'), isFalse);
    });

    test('Backend validation error 422 MISSING_SELLER_INFO accurately surfaces',
        () async {
      final adapter = TestMockAdapter((options) async {
        if (options.path.contains(ApiConstants.registerEndpoint)) {
          return TestMockAdapter.json({
            'success': false,
            'error': {
              'code': 'MISSING_SELLER_INFO',
              'message': 'Company name is required for seller registration',
            },
          }, statusCode: 422);
        }
        return TestMockAdapter.json({'success': false}, statusCode: 404);
      });

      final client = ApiClient(
        baseUrl: 'http://test.api',
        tokenStorage: storage,
        adapter: adapter,
      );
      final authService = AuthApiService(client: client);

      try {
        await authService.register(
          email: 'seller@invalid.com',
          password: 'password123',
          role: 'seller',
          name: 'Invalid Seller',
        );
        fail('Should throw ApiException');
      } on ApiException catch (e) {
        expect(e.code, 'MISSING_SELLER_INFO');
        expect(e.message, 'Company name is required for seller registration');
        expect(e.statusCode, 422);
      }
    });

    test('Backend validation error 409 EMAIL_ALREADY_EXISTS accurately surfaces',
        () async {
      final adapter = TestMockAdapter((options) async {
        if (options.path.contains(ApiConstants.registerEndpoint)) {
          return TestMockAdapter.json({
            'success': false,
            'error': {
              'code': 'EMAIL_ALREADY_EXISTS',
              'message': 'An account with this email address already exists',
            },
          }, statusCode: 409);
        }
        return TestMockAdapter.json({'success': false}, statusCode: 404);
      });

      final client = ApiClient(
        baseUrl: 'http://test.api',
        tokenStorage: storage,
        adapter: adapter,
      );
      final authService = AuthApiService(client: client);

      try {
        await authService.register(
          email: 'existing@pangan.com',
          password: 'password123',
          role: 'seller',
          name: 'Duplicate Seller',
          companyName: 'PT Pangan Mandiri',
        );
        fail('Should throw ApiException');
      } on ApiException catch (e) {
        expect(e.code, 'EMAIL_ALREADY_EXISTS');
        expect(e.message, 'An account with this email address already exists');
        expect(e.statusCode, 409);
      }
    });
  });

  group('ARDI-72 Supabase Complete Removal Verification', () {
    test('lib/main.dart does not contain Supabase initialization or import', () {
      final mainCode = File('lib/main.dart').readAsStringSync();
      expect(mainCode.toLowerCase().contains('supabase'), isFalse,
          reason: 'Supabase import/init must be removed from main.dart');
    });

    test('pubspec.yaml does not contain supabase_flutter dependency', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.toLowerCase().contains('supabase_flutter'), isFalse,
          reason: 'supabase_flutter must be removed from dependencies');
    });

    test('Entire lib directory has zero references to Supabase', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(content.toLowerCase().contains('supabase'), isFalse,
            reason: '${file.path} must not reference supabase');
      }
    });
  });

  group('ARDI-72 Backend-Supported Endpoint Integrations', () {
    test('ListingApiService maps GET /listings and posts to POST /listings',
        () async {
      final adapter = TestMockAdapter((options) async {
        if (options.method == 'GET' && options.path.contains('/listings')) {
          return TestMockAdapter.json({
            'success': true,
            'data': [
              {
                'id': 10,
                'product_id': 1,
                'seller_id': 2,
                'batch_number': 'BATCH-001',
                'qty': 50,
                'normal_price': 100000.0,
                'start_price': 75000.0,
                'min_price': 50000.0,
                'current_price': 70000.0,
                'drop_interval_minutes': 60,
                'drop_percentage': 5.0,
                'expiry_date': '2026-12-31',
                'auction_start_at': '2026-10-01T00:00:00Z',
                'auction_end_at': '2026-12-31T00:00:00Z',
                'status': 'active',
                'created_at': '2026-10-01T00:00:00Z',
                'seller_company': 'PT Pangan Sejahtera',
                'warehouse_city': 'Jakarta',
                'product': {
                  'name': 'Beras Premium 5kg',
                  'category': 'Flour & Grain',
                  'storage_type': 'ambient',
                  'default_unit': 'karung',
                },
              }
            ],
          });
        }
        if (options.method == 'POST' && options.path.contains('/listings')) {
          return TestMockAdapter.json({
            'success': true,
            'data': {'id': 99},
          }, statusCode: 201);
        }
        return TestMockAdapter.json({'success': false}, statusCode: 404);
      });

      final client = ApiClient(
        baseUrl: 'http://test.api',
        tokenStorage: InMemoryTokenStorage(),
        adapter: adapter,
      );
      final listingService = ListingApiService(client: client);

      final listings = await listingService.fetchRemoteListings(search: 'Beras');
      expect(listings.length, 1);
      expect(listings.first.id, 10);
      expect(listings.first.productName, 'Beras Premium 5kg');
      expect(listings.first.sellerCompany, 'PT Pangan Sejahtera');

      const draft = DraftListingModel(
        productName: 'Minyak Goreng',
        category: 'Oil',
        batchNumber: 'MG-01',
        qty: 20,
        normalPrice: 50000,
        minPrice: 30000,
        expiryDate: '2026-11-01',
        createdAt: '2026-10-01T00:00:00Z',
        updatedAt: '2026-10-01T00:00:00Z',
      );
      final newId = await listingService.uploadDraftListing(draft);
      expect(newId, 99);
    });

    test('OrderApiService maps GET /orders and GET /orders/{id}', () async {
      final adapter = TestMockAdapter((options) async {
        if (options.path == '/orders') {
          return TestMockAdapter.json({
            'success': true,
            'data': [
              {
                'id': 501,
                'listing_id': 10,
                'buyer_id': 20,
                'qty': 5,
                'final_unit_price': 70000.0,
                'total_price': 350000.0,
                'status': 'paid',
                'created_at': '2026-10-10T10:00:00Z',
                'product_detail': {
                  'product_name': 'Beras Premium 5kg',
                  'category': 'Flour & Grain',
                  'batch_number': 'BATCH-001',
                  'warehouse_address': 'Jl. Pergudangan 1',
                  'warehouse_lat': -6.2,
                  'warehouse_lng': 106.8,
                },
              }
            ],
          });
        }
        if (options.path == '/orders/501') {
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'id': 501,
              'listing_id': 10,
              'buyer_id': 20,
              'qty': 5,
              'final_unit_price': 70000.0,
              'total_price': 350000.0,
              'status': 'paid',
              'created_at': '2026-10-10T10:00:00Z',
              'product_detail': {
                'product_name': 'Beras Premium 5kg',
                'category': 'Flour & Grain',
                'batch_number': 'BATCH-001',
                'warehouse_address': 'Jl. Pergudangan 1',
                'warehouse_lat': -6.2,
                'warehouse_lng': 106.8,
              },
            },
          });
        }
        return TestMockAdapter.json({'success': false}, statusCode: 404);
      });

      final client = ApiClient(
        baseUrl: 'http://test.api',
        tokenStorage: InMemoryTokenStorage(),
        adapter: adapter,
      );
      final orderService = OrderApiService(client: client);

      final orders = await orderService.fetchRemoteOrders();
      expect(orders.length, 1);
      expect(orders.first.id, 501);
      expect(orders.first.productName, 'Beras Premium 5kg');
      expect(orders.first.warehouseAddress, 'Jl. Pergudangan 1');

      final orderDetail = await orderService.fetchRemoteOrderDetail(501);
      expect(orderDetail.id, 501);
      expect(orderDetail.totalPrice, 350000.0);
    });

    test('FeedbackApiService transmits kesan and saran to POST /feedback',
        () async {
      Map<String, dynamic>? postedPayload;
      final adapter = TestMockAdapter((options) async {
        if (options.path == '/feedback') {
          postedPayload = options.data as Map<String, dynamic>;
          return TestMockAdapter.json({
            'success': true,
            'data': {
              'id': 1,
              'user_id': 10,
              'kesan': 'Materi sangat aplikatif',
              'saran': 'Tingkatkan dokumentasi API',
              'submitted_at': '2026-10-16T12:00:00Z',
            },
          }, statusCode: 201);
        }
        return TestMockAdapter.json({'success': false}, statusCode: 404);
      });

      final client = ApiClient(
        baseUrl: 'http://test.api',
        tokenStorage: InMemoryTokenStorage(),
        adapter: adapter,
      );
      final feedbackService = FeedbackApiService(client: client);

      final result = await feedbackService.submitFeedback(
        kesan: 'Materi sangat aplikatif',
        saran: 'Tingkatkan dokumentasi API',
      );

      expect(result['id'], 1);
      expect(postedPayload, isNotNull);
      expect(postedPayload!['kesan'], 'Materi sangat aplikatif');
      expect(postedPayload!['saran'], 'Tingkatkan dokumentasi API');
    });

    test('UserProfile.fromJson extracts nested seller and buyer profile fields',
        () {
      final sellerJson = {
        'id': 1,
        'email': 'seller@corp.com',
        'role': 'seller',
        'name': 'Budi Display',
        'phone': '0812345678',
        'photo_url': null,
        'seller': {
          'id': 10,
          'company_name': 'PT Distribusi Utama',
          'address': 'Kawasan Industri Pulo Gadung',
          'city': 'Jakarta Timur',
        },
      };

      final sellerProfile = UserProfile.fromJson(sellerJson);
      expect(sellerProfile.companyName, 'PT Distribusi Utama');
      expect(sellerProfile.city, 'Jakarta Timur');
      expect(sellerProfile.address, 'Kawasan Industri Pulo Gadung');
      expect(sellerProfile.role, 'seller');

      final buyerJson = {
        'id': 2,
        'email': 'buyer@resto.com',
        'role': 'buyer',
        'name': 'Siti Buyer',
        'buyer': {
          'id': 20,
          'business_type': 'catering',
          'address': 'Jl. Margonda No. 12',
        },
      };

      final buyerProfile = UserProfile.fromJson(buyerJson);
      expect(buyerProfile.businessType, 'catering');
      expect(buyerProfile.address, 'Jl. Margonda No. 12');
      expect(buyerProfile.role, 'buyer');
    });
  });
}
