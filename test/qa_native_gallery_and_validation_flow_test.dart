import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/storage/token_storage.dart';
import 'package:recovera/data/repositories/auth_repository.dart';
import 'package:recovera/data/services/auth_api_service.dart';
import 'package:recovera/features/seller/repositories/seller_repository.dart';
import 'package:recovera/features/seller/screens/upload_stock_flow_screen.dart';
import 'package:recovera/features/seller/services/seller_api_service.dart';

class _TestMockAdapter implements HttpClientAdapter {
  _TestMockAdapter(this.handler);

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

  group('ARDI-96 Native Gallery Image Picker & Seller Draft Validation Tests', () {
    late SellerRepository mockRepo;
    Map<String, dynamic>? lastDraftPayload;

    setUp(() async {
      lastDraftPayload = null;
      final storage = InMemoryTokenStorage();
      final adapter = _TestMockAdapter((options) async {
        if (options.path.contains('/listings/seller/inventory/drafts')) {
          lastDraftPayload = options.data as Map<String, dynamic>?;
          return _TestMockAdapter.json({
            'success': true,
            'data': {
              'listing': {
                'id': 88,
                'product_id': 105,
                'batch_number': 'LOT-LOT-88',
                'qty': 250,
                'normal_price': 20000.0,
                'start_price': 14000.0,
                'min_price': 6000.0,
                'current_price': 14000.0,
                'expiry_date': '2026-08-15T00:00:00Z',
                'status': 'draft',
                'product': {
                  'id': 105,
                  'name': 'Keju Mozzarella 250g',
                  'category': 'Produk Olahan Susu & Dairy',
                  'default_unit': 'box',
                  'image_url': lastDraftPayload?['image_url'],
                },
              },
              'validation': {
                'valid': true,
                'errors': <String>[],
                'status': 'draft',
              },
              'price_recommendation': {
                'suggested_price': 14000.0,
                'discount_pct': 30.0,
                'rationale': 'Diskon awal 30% berdasarkan umur simpan.',
                'next_drop_at': '2026-05-01T12:00:00Z',
              },
            },
          });
        }

        if (options.path.contains('/validate')) {
          return _TestMockAdapter.json({
            'success': true,
            'data': {
              'valid': true,
              'errors': <String>[],
              'status': 'review',
            },
          });
        }

        if (options.path.contains('/recommendation')) {
          return _TestMockAdapter.json({
            'success': true,
            'data': {
              'recommendation': {
                'suggested_price': 14000.0,
                'discount_pct': 30.0,
                'rationale': 'Diskon awal 30% berdasarkan umur simpan.',
                'next_drop_at': '2026-05-01T12:00:00Z',
              },
              'price_warning': false,
              'accepted_range': {'minimum': 11200.0, 'maximum': 16800.0},
            },
          });
        }

        if (options.path.contains('/publish')) {
          return _TestMockAdapter.json({
            'success': true,
            'data': {
              'id': 88,
              'product_id': 105,
              'batch_number': 'LOT-LOT-88',
              'qty': 250,
              'normal_price': 20000.0,
              'start_price': 14000.0,
              'min_price': 6000.0,
              'current_price': 14000.0,
              'expiry_date': '2026-08-15T00:00:00Z',
              'status': 'active',
              'product': {
                'id': 105,
                'name': 'Keju Mozzarella 250g',
                'category': 'Produk Olahan Susu & Dairy',
                'default_unit': 'box',
              },
            },
          });
        }

        return _TestMockAdapter.json({'success': true, 'data': []});
      });

      final dio = Dio()..httpClientAdapter = adapter;
      final apiClient = ApiClient(dio: dio, tokenStorage: storage);
      mockRepo = SellerRepository(apiService: SellerApiService(client: apiClient));

      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'seller-token',
          refreshToken: 'seller-refresh',
          userId: 101,
          role: 'seller',
        ),
      );
      final authRepo = AuthRepository(
        authApiService: AuthApiService(client: apiClient),
        tokenStorage: storage,
      );
      await authRepo.init();
      AuthRepository.instance = authRepo;
    });

    testWidgets('Tapping photo upload target invokes native gallery picker without URL input dialog',
        (tester) async {
      int pickerCallCount = 0;
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: mockRepo,
            onPickImage: () async {
              pickerCallCount++;
              return XFile.fromData(
                fakeBytes,
                name: 'test_product.jpg',
                path: 'gallery://device_cache/test_product.jpg',
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify that the old URL text input dialog does NOT exist
      expect(find.text('Gunakan URL gambar produk atau pilih preset terverifikasi:'), findsNothing);
      expect(find.text('Pilih Foto Produk'), findsNothing);

      // Verify upload box prompt text
      expect(find.text('Pilih Foto dari Galeri'), findsOneWidget);
      expect(find.byKey(const Key('photo_upload_tap_target')), findsOneWidget);

      // Tap photo upload box
      await tester.tap(find.byKey(const Key('photo_upload_tap_target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify native gallery picker callback was called directly
      expect(pickerCallCount, 1);

      // Verify preview is immediately displayed on form
      expect(find.byKey(const Key('photo_upload_preview_container')), findsOneWidget);
      expect(find.text('Foto Galeri Terpilih'), findsOneWidget);
      expect(find.byKey(const Key('btn_change_photo')), findsOneWidget);

      // Verify URL dialog is never shown
      expect(find.text('Gunakan URL gambar produk atau pilih preset terverifikasi:'), findsNothing);
    });

    testWidgets('Selecting an image updates preview and submits picked image payload to backend',
        (tester) async {
      final fakeBytes = Uint8List.fromList([10, 20, 30]);

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: mockRepo,
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

      // Tap photo upload to pick from gallery
      await tester.tap(find.byKey(const Key('photo_upload_tap_target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Preview is displayed
      expect(find.byKey(const Key('photo_upload_preview_container')), findsOneWidget);
      expect(find.text('Foto Galeri Terpilih'), findsOneWidget);

      // Submit Step 1 -> 'Lanjut ke Validasi'
      await tester.ensureVisible(find.byKey(const Key('btn_submit_step1')));
      await tester.tap(find.byKey(const Key('btn_submit_step1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify draft payload contains the picked image path
      expect(lastDraftPayload, isNotNull);
      expect(lastDraftPayload!['image_url'], '/data/user/0/recovera/cache/mozzarella.jpg');

      // Verify smooth transition to Step 2: Quality Validation
      expect(find.text('Memeriksa Produk'), findsOneWidget);
      expect(find.text('Kriteria Validasi Pangan'), findsOneWidget);
    });

    testWidgets('Re-picking photo via Ganti Foto button updates preview with new photo',
        (tester) async {
      int pickIndex = 0;
      final images = [
        XFile.fromData(Uint8List.fromList([1, 1, 1]), path: 'photo_1.jpg'),
        XFile.fromData(Uint8List.fromList([2, 2, 2]), path: 'photo_2.jpg'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: mockRepo,
            onPickImage: () async {
              final img = images[pickIndex];
              pickIndex++;
              return img;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Pick first photo
      await tester.tap(find.byKey(const Key('photo_upload_tap_target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('photo_upload_preview_container')), findsOneWidget);
      expect(pickIndex, 1);

      // Tap 'Ganti Foto'
      await tester.tap(find.byKey(const Key('btn_change_photo')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(pickIndex, 2);
      expect(find.byKey(const Key('photo_upload_preview_container')), findsOneWidget);
    });

    testWidgets('Handling gallery cancellation gracefully keeps form responsive',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: mockRepo,
            onPickImage: () async {
              return null; // User cancelled gallery picker
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap photo upload
      await tester.tap(find.byKey(const Key('photo_upload_tap_target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // No preview, prompt remains visible and interactive
      expect(find.text('Pilih Foto dari Galeri'), findsOneWidget);
      expect(find.byKey(const Key('btn_submit_step1')), findsOneWidget);
    });

    testWidgets('Handling gallery exception displays error feedback gracefully',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: mockRepo,
            onPickImage: () async {
              throw Exception('Permission denied by user');
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap photo upload
      await tester.tap(find.byKey(const Key('photo_upload_tap_target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Error message is displayed in SnackBar
      expect(find.textContaining('Gagal mengakses galeri'), findsWidgets);
    });

    testWidgets('End-to-end seller upload flow: gallery selection to Step 4 publish',
        (tester) async {
      final fakeBytes = Uint8List.fromList([50, 60, 70]);

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: mockRepo,
            onPickImage: () async {
              return XFile.fromData(fakeBytes, path: 'final_product.png');
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Pick photo from gallery
      await tester.tap(find.byKey(const Key('photo_upload_tap_target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Foto Galeri Terpilih'), findsOneWidget);

      // 2. Submit Step 1 -> Advance to Step 2
      await tester.ensureVisible(find.byKey(const Key('btn_submit_step1')));
      await tester.tap(find.byKey(const Key('btn_submit_step1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Memeriksa Produk'), findsOneWidget);

      // Advance validation timer
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      // 3. Step 2 -> Step 3
      expect(find.byKey(const Key('btn_proceed_to_pricing')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('btn_proceed_to_pricing')));
      await tester.tap(find.byKey(const Key('btn_proceed_to_pricing')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Rekomendasi Cerdas'), findsOneWidget);

      // 4. Step 3 -> Step 4
      await tester.ensureVisible(find.byKey(const Key('btn_use_recommendation')));
      await tester.tap(find.byKey(const Key('btn_use_recommendation')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Review & Publish'), findsWidgets);
      expect(find.text('Ringkasan Produk'), findsOneWidget);

      // 5. Publish
      await tester.ensureVisible(find.byKey(const Key('btn_publish_stock')));
      await tester.tap(find.byKey(const Key('btn_publish_stock')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sukses Dipublikasi!'), findsOneWidget);
    });
  });
}
