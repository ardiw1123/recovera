import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
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

  group('Issue: Validasi Konteks OCR & Penolakan Non-Pangan (A1-A5)', () {
    testWidgets('A1, A4: Menolak gambar non-faktur dengan pesan peringatan merah dan tidak mengisi formulir',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      final adapter = _MockHttpAdapter((options) async {
        if (options.path.contains('/ai/invoice')) {
          return _MockHttpAdapter.json({
            'success': true,
            'data': {
              'invoice_number': null,
              'supplier_name': null,
              'parsed_items': [],
              'fallback_used': false,
              'rejected': true,
              'rejection_reason': 'Gambar yang dikirim bukan faktur atau produk pangan',
            }
          });
        }
        return _MockHttpAdapter.json({'success': false}, statusCode: 404);
      });

      final client = ApiClient(adapter: adapter, tokenStorage: InMemoryTokenStorage());
      final repo = SellerRepository(apiService: SellerApiService(client: client));

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: repo,
            onPickInvoiceImage: () async => XFile.fromData(
              Uint8List(50 * 1024),
              name: 'foto_kucing.jpg',
              path: '/tmp/foto_kucing.jpg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ocrBtn = find.byKey(const Key('btn_scan_invoice_ocr'));
      expect(ocrBtn, findsOneWidget);

      await tester.ensureVisible(ocrBtn);
      await tester.tap(ocrBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Memastikan pesan penolakan tampil dalam bahasa Indonesia
      expect(find.text('Gambar yang dikirim bukan faktur atau produk pangan'), findsOneWidget);
      expect(find.byKey(const Key('ocr_rejection_snackbar')), findsOneWidget);

      // Memastikan form produk tetap kosong
      expect(find.text('Susu UHT Full Cream 1L'), findsNothing);
      expect(find.text('Tepung Terigu Segitiga Biru 1kg'), findsNothing);
    });

    testWidgets('A3: Menampilkan indikator kuning peringatan saat fallback_used == true (mode offline/demo)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      final adapter = _MockHttpAdapter((options) async {
        if (options.path.contains('/ai/invoice')) {
          return _MockHttpAdapter.json({
            'success': true,
            'data': {
              'invoice_number': 'INV-20261024-001',
              'supplier_name': 'PT Sumber Pangan Distribusi',
              'fallback_used': true,
              'rejected': false,
              'parsed_items': [
                {
                  'product_name': 'Susu UHT Full Cream 1L',
                  'brand': 'Ultra Milk',
                  'category': 'Produk Olahan Susu & Dairy',
                  'quantity': 50,
                  'unit': 'karton',
                  'expiry_date': '2026-12-10',
                  'normal_price': 210000.0,
                }
              ]
            }
          });
        }
        return _MockHttpAdapter.json({'success': false}, statusCode: 404);
      });

      final client = ApiClient(adapter: adapter, tokenStorage: InMemoryTokenStorage());
      final repo = SellerRepository(apiService: SellerApiService(client: client));

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: repo,
            onPickInvoiceImage: () async => XFile.fromData(
              Uint8List(50 * 1024),
              name: 'faktur_offline.jpg',
              path: '/tmp/faktur_offline.jpg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ocrBtn = find.byKey(const Key('btn_scan_invoice_ocr'));
      await tester.ensureVisible(ocrBtn);
      await tester.tap(ocrBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Form terisi
      expect(find.text('Susu UHT Full Cream 1L'), findsOneWidget);

      // Peringatan kuning fallback tampil
      expect(find.byKey(const Key('ocr_fallback_snackbar')), findsOneWidget);
      expect(
        find.textContaining('Mode demo/offline aktif'),
        findsOneWidget,
      );
    });

    testWidgets('A5: User dapat langsung upload ulang gambar faktur setelah ditolak tanpa restart alur',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      int callCount = 0;
      final adapter = _MockHttpAdapter((options) async {
        if (options.path.contains('/ai/invoice')) {
          callCount++;
          if (callCount == 1) {
            // Panggilan pertama: ditolak karena bukan faktur
            return _MockHttpAdapter.json({
              'success': true,
              'data': {
                'rejected': true,
                'rejection_reason': 'Gambar yang dikirim bukan faktur atau produk pangan',
                'parsed_items': [],
                'fallback_used': false,
              }
            });
          } else {
            // Panggilan kedua: faktur valid
            return _MockHttpAdapter.json({
              'success': true,
              'data': {
                'rejected': false,
                'fallback_used': false,
                'invoice_number': 'INV-VALID-01',
                'parsed_items': [
                  {
                    'product_name': 'Beras Ramos 5kg',
                    'brand': 'Ramos',
                    'category': 'Flour & Grain',
                    'quantity': 20,
                    'unit': 'karung',
                    'expiry_date': '2026-12-30',
                    'normal_price': 75000.0,
                  }
                ]
              }
            });
          }
        }
        return _MockHttpAdapter.json({'success': false}, statusCode: 404);
      });

      final client = ApiClient(adapter: adapter, tokenStorage: InMemoryTokenStorage());
      final repo = SellerRepository(apiService: SellerApiService(client: client));

      int pickCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: repo,
            onPickInvoiceImage: () async {
              pickCount++;
              if (pickCount == 1) {
                return XFile.fromData(
                  Uint8List(10 * 1024),
                  name: 'selfie.jpg',
                  path: '/tmp/selfie.jpg',
                );
              } else {
                return XFile.fromData(
                  Uint8List(10 * 1024),
                  name: 'faktur_asli.jpg',
                  path: '/tmp/faktur_asli.jpg',
                );
              }
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ocrBtn = find.byKey(const Key('btn_scan_invoice_ocr'));

      // 1. Scan pertama (selfie) -> ditolak
      await tester.ensureVisible(ocrBtn);
      await tester.tap(ocrBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ocr_rejection_snackbar')), findsOneWidget);
      expect(find.text('Beras Ramos 5kg'), findsNothing);

      // Bersihkan snackbar
      ScaffoldMessenger.of(tester.element(find.byType(UploadStockFlowScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      // 2. Scan kedua langsung dari tombol yang sama tanpa restart alur
      await tester.tap(ocrBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ocr_success_snackbar')), findsOneWidget);
      expect(find.text('Beras Ramos 5kg'), findsOneWidget);
      expect(find.text('75000'), findsOneWidget);
    });
  });
}
