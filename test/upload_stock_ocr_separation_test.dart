import 'dart:convert';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/storage/token_storage.dart';
import 'package:recovera/data/repositories/auth_repository.dart';
import 'package:recovera/features/auth/models/user_profile.dart';
import 'package:recovera/features/seller/repositories/seller_repository.dart';
import 'package:recovera/features/seller/screens/upload_stock_flow_screen.dart';
import 'package:recovera/features/seller/services/seller_api_service.dart';

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
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    AuthRepository.instance.currentUserProfile = const UserProfile(
      id: 42,
      email: 'seller@recovera.id',
      name: 'Seller Resmi',
      role: 'seller',
      companyName: 'PT Pangan Berkah',
    );
  });

  tearDown(() {
    AuthRepository.instance.currentUserProfile = null;
  });

  group('Issue: Pemisahan Foto Produk & OCR Faktur', () {
    testWidgets('Teks informasi upload menampilkan batas maksimal 2MB',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: UploadStockFlowScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Format JPG atau PNG (Maks. 2MB)'), findsOneWidget);
    });

    testWidgets(
        'Upload foto produk menolak file yang melebihi batas maksimal 2 MB',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      // Simulasi file berukuran 2.5 MB (2.5 * 1024 * 1024 bytes)
      final oversizeBytes = (2.5 * 1024 * 1024).toInt();
      final oversizedBytes = Uint8List(oversizeBytes);

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            onPickImage: () async => XFile.fromData(
              oversizedBytes,
              name: 'foto_besar.png',
              path: '/dummy/foto_besar.png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uploadTarget = find.byKey(const Key('photo_upload_tap_target'));
      expect(uploadTarget, findsOneWidget);

      await tester.tap(uploadTarget);
      await tester.pumpAndSettle();

      // Memastikan muncul pesan error batas 2 MB
      expect(
        find.textContaining('melebihi batas maksimal 2 MB'),
        findsWidgets,
      );

      // Pastikan tombol submit tetap menolak karena foto belum valid
      ScaffoldMessenger.of(tester.element(find.byType(UploadStockFlowScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('btn_submit_step1'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Foto produk wajib diunggah'), findsWidgets);
    });

    testWidgets(
        'Upload foto produk sukses jika file <= 2 MB dan tersimpan ke state produk',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      // Simulasi file berukuran 500 KB (500 * 1024 bytes)
      const validSizeBytes = 500 * 1024;
      final validBytes = Uint8List(validSizeBytes);

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            onPickImage: () async => XFile.fromData(
              validBytes,
              name: 'foto_produk.jpg',
              path: 'https://images.unsplash.com/photo-1550583724-b2692b85b150',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uploadTarget = find.byKey(const Key('photo_upload_tap_target'));
      await tester.tap(uploadTarget);
      await tester.pumpAndSettle();

      // Preview foto muncul bersama tombol Ganti Foto
      expect(find.byKey(const Key('photo_upload_preview_container')), findsOneWidget);
      expect(find.byKey(const Key('btn_change_photo')), findsOneWidget);
    });

    testWidgets(
        'Tombol OCR faktur berada di dalam kartu Informasi Produk dan tidak menimpa foto produk',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      Map<String, dynamic>? capturedPayload;

      final adapter = _MockHttpAdapter((options) async {
        if (options.path.contains('/ai/invoice')) {
          return _MockHttpAdapter.json({
            'success': true,
            'data': {
              'invoice_number': 'INV-TEST-2026',
              'fallback_used': false,
              'parsed_items': [
                {
                  'product_name': 'Minyak Goreng Sawit 2L',
                  'brand': 'Bimoli',
                  'category': 'Minyak & Lemak',
                  'quantity': 350,
                  'unit': 'jerigen',
                  'expiry_date': '2026-12-25',
                  'normal_price': 38000.0,
                }
              ]
            }
          });
        }
        if (options.path.contains('/listings/seller/inventory/drafts') ||
            options.path.contains('/listings/draft')) {
          if (options.data is Map<String, dynamic>) {
            capturedPayload = options.data as Map<String, dynamic>;
          } else {
            capturedPayload = jsonDecode(options.data.toString()) as Map<String, dynamic>;
          }
          return _MockHttpAdapter.json({
            'success': true,
            'data': {
              'id': 999,
              'product_id': 10,
              'seller_id': 42,
              'batch_number': 'LOT-2026-X1',
              'qty': 350,
              'normal_price': 38000.0,
              'start_price': 22800.0,
              'min_price': 15200.0,
              'current_price': 22800.0,
              'expiry_date': '2026-12-25',
              'status': 'draft',
              'created_at': '2026-10-22T00:00:00Z',
              'product_name': 'Minyak Goreng Sawit 2L',
              'category': 'Minyak & Lemak',
              'brand': 'Bimoli',
              'default_unit': 'jerigen',
              'storage_type': 'ambient',
              'image_url': 'https://example.com/foto_produk_asli.jpg',
            }
          }, statusCode: 201);
        }
        return _MockHttpAdapter.json({'success': false}, statusCode: 404);
      });

      final client =
          ApiClient(adapter: adapter, tokenStorage: InMemoryTokenStorage());
      final repo = SellerRepository(apiService: SellerApiService(client: client));

      const productPhotoUrl = 'https://example.com/foto_produk_asli.jpg';

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: repo,
            initialImageUrl: productPhotoUrl,
            onPickInvoiceImage: () async => XFile.fromData(
              Uint8List(100 * 1024),
              name: 'foto_faktur_kertas.jpg',
              path: '/tmp/faktur_kertas.jpg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pastikan tombol OCR faktur ada di dalam kartu Informasi Produk
      final ocrBtn = find.byKey(const Key('btn_scan_invoice_ocr'));
      expect(ocrBtn, findsOneWidget);

      // Jalankan pemindaian OCR faktur
      await tester.ensureVisible(ocrBtn);
      await tester.tap(ocrBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Form otomatis terisi oleh OCR
      expect(find.text('Minyak Goreng Sawit 2L'), findsOneWidget);
      expect(find.text('350'), findsOneWidget);
      expect(find.text('38000'), findsOneWidget);
      expect(find.text('Minyak & Lemak'), findsWidgets);

      // Bersihkan snackbar notifikasi OCR sebelum submit
      ScaffoldMessenger.of(tester.element(find.byType(UploadStockFlowScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      // Submit Step 1
      final submitBtn = find.byKey(const Key('btn_submit_step1'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verifikasi bahwa gambar yang dikirim ke backend adalah foto produk asli,
      // BUKAN foto faktur kertas
      expect(capturedPayload, isNotNull);
      expect(capturedPayload!['image_url'], equals(productPhotoUrl));
      expect(capturedPayload!['image_url'].toString(), isNot(contains('faktur_kertas')));
    });
  });
}
