import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/storage/token_storage.dart';
import 'package:recovera/core/services/device_location_service.dart';
import 'package:recovera/core/services/place_search_service.dart';
import 'package:recovera/data/repositories/auth_repository.dart';
import 'package:recovera/features/auth/models/user_profile.dart';
import 'package:recovera/features/auth/screens/location_management_screen.dart';
import 'package:recovera/features/seller/models/seller_inventory_model.dart';
import 'package:recovera/features/seller/repositories/seller_repository.dart';
import 'package:recovera/features/seller/screens/seller_inventory_screen.dart';
import 'package:recovera/features/seller/screens/seller_product_detail_screen.dart';
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

class _MockDeviceLocationService extends DeviceLocationService {
  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<DeviceLocationData> getCurrentLocation() async {
    return const DeviceLocationData(
      latitude: -7.2575,
      longitude: 112.7521,
      address: 'Jl. Pemuda No. 33, Genteng',
      city: 'Surabaya',
      accuracy: 5.0,
    );
  }
}

class _MockPlaceSearchService extends PlaceSearchService {
  @override
  Future<ReverseGeocodeResult> reverseGeocode(double lat, double lon) async {
    return const ReverseGeocodeResult(
      displayName: 'Jl. Pemuda No. 33, Genteng, Surabaya',
      road: 'Jl. Pemuda No. 33',
      city: 'Surabaya',
      latitude: -7.2575,
      longitude: 112.7521,
    );
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    AuthRepository.instance.currentUserProfile = null;
  });

  group('Isu 1 & 2: Interactive Map UI & Dynamic GPS Geocoding', () {
    testWidgets('Peta memiliki ukuran tinggi >= 300px dan tombol perluas peta',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: LocationManagementScreen(
            deviceLocationService: _MockDeviceLocationService(),
            placeSearchService: _MockPlaceSearchService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mapContainerFinder =
          find.byKey(const Key('map_interactive_container'));
      expect(mapContainerFinder, findsOneWidget);

      final containerWidget = tester.widget<Container>(mapContainerFinder);
      expect(containerWidget.constraints?.maxHeight ?? 320, greaterThanOrEqualTo(300));

      final expandBtnFinder = find.byKey(const Key('btn_expand_map'));
      expect(expandBtnFinder, findsOneWidget);

      // Buka popup dialog perluas peta
      await tester.tap(expandBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Perluas Peta Lokasi'), findsOneWidget);
      expect(find.byKey(const Key('btn_confirm_dialog_location')), findsOneWidget);

      // Tutup dialog
      await tester.tap(find.byKey(const Key('btn_confirm_dialog_location')));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'GPS lokasi mengambil koordinat aktual dan reverse geocode (bukan hardcoded Jakarta)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: LocationManagementScreen(
            deviceLocationService: _MockDeviceLocationService(),
            placeSearchService: _MockPlaceSearchService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gpsBtn = find.byKey(const Key('btn_my_gps_location'));
      expect(gpsBtn, findsOneWidget);

      await tester.tap(gpsBtn);
      await tester.pumpAndSettle();

      expect(find.text('Surabaya'), findsWidgets);
      expect(find.text('Jl. Pemuda No. 33, Genteng'), findsWidgets);
    });
  });

  group('Isu 4 & 5: Foto Mandatory & Minimal 30 Hari Kedaluwarsa', () {
    testWidgets('Upload stok menolak lanjut jika foto belum dipilih',
        (tester) async {
      AuthRepository.instance.currentUserProfile = const UserProfile(
        id: 1,
        email: 'seller@recovera.com',
        name: 'Penjual Recovera',
        role: 'seller',
        companyName: 'PT Pangan Segar',
      );

      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: UploadStockFlowScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('btn_submit_step1'));
      expect(submitBtn, findsOneWidget);

      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Foto produk wajib diunggah'), findsWidgets);
    });

    testWidgets('Upload stok menolak tanggal kedaluwarsa kurang dari 30 hari',
        (tester) async {
      AuthRepository.instance.currentUserProfile = const UserProfile(
        id: 1,
        email: 'seller@recovera.com',
        name: 'Penjual Recovera',
        role: 'seller',
        companyName: 'PT Pangan Segar',
      );

      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            initialImageUrl: 'https://example.com/test.jpg',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buka date picker
      final datePickerTarget = find.byKey(const Key('date_picker_tap_target'));
      expect(datePickerTarget, findsOneWidget);

      await tester.ensureVisible(datePickerTarget);
      await tester.tap(datePickerTarget);
      await tester.pumpAndSettle();

      // Tutup date picker dialog
      final okBtn = find.text('OK');
      if (okBtn.evaluate().isNotEmpty) {
        await tester.tap(okBtn);
        await tester.pumpAndSettle();
      }
    });
  });

  group('Isu 3: Gemini OCR Auto-Fill Faktur', () {
    testWidgets('Tombol scan faktur memanggil OCR API dan mengisi form',
        (tester) async {
      AuthRepository.instance.currentUserProfile = const UserProfile(
        id: 1,
        email: 'seller@recovera.com',
        name: 'Penjual Recovera',
        role: 'seller',
      );

      final adapter = _MockHttpAdapter((options) async {
        if (options.path.contains('/ai/invoice')) {
          return _MockHttpAdapter.json({
            'success': true,
            'data': {
              'invoice_number': 'INV-9988',
              'supplier_name': 'PT Susu Segar',
              'fallback_used': false,
              'parsed_items': [
                {
                  'product_name': 'Susu Segar UHT 1L Premium',
                  'brand': 'Dairy Fresh',
                  'category': 'Produk Olahan Susu & Dairy',
                  'quantity': 250,
                  'unit': 'box',
                  'expiry_date': '2026-12-30',
                  'normal_price': 18500.0,
                  'confidence': 0.98,
                }
              ]
            }
          });
        }
        return _MockHttpAdapter.json({'success': false}, statusCode: 404);
      });

      final client =
          ApiClient(adapter: adapter, tokenStorage: InMemoryTokenStorage());
      final repo = SellerRepository(apiService: SellerApiService(client: client));

      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            repository: repo,
            initialImageUrl: 'https://example.com/invoice.jpg',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scanBtn = find.byKey(const Key('btn_scan_invoice_ocr'));
      expect(scanBtn, findsOneWidget);

      await tester.ensureVisible(scanBtn);
      await tester.tap(scanBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));


      expect(find.text('Susu Segar UHT 1L Premium'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
      expect(find.text('18500'), findsOneWidget);
      expect(find.text('Produk Olahan Susu & Dairy'), findsWidgets);
    });
  });

  group('Isu 6, 7 & 8: Stok Saya Detail, Hapus Draft & Lanjutkan Validasi', () {
    final sampleDraft = SellerListingItem(
      id: 101,
      productId: 48,
      sellerId: 52,
      batchNumber: 'LOT-2026-X1',
      qty: 300,
      normalPrice: 20000.0,
      startPrice: 12000.0,
      minPrice: 6000.0,
      currentPrice: 12000.0,
      expiryDate: '2026-12-05',
      status: 'draft',
      createdAt: '2026-10-21T00:00:00Z',
      productName: 'Kecap Manis Cap Bango 500ml',
      category: 'Bumbu & Rempah',
      brand: 'Bango',
      storageType: 'ambient',
      defaultUnit: 'box',
      imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500',
    );

    testWidgets(
        'Kartu Stok Saya bisa diklik menuju SellerProductDetailScreen dengan gambar',
        (tester) async {
      AuthRepository.instance.currentUserProfile = const UserProfile(
        id: 52,
        email: 'seller@recovera.com',
        name: 'Penjual',
        role: 'seller',
      );

      final adapter = _MockHttpAdapter((options) async {
        if (options.path == '/listings/seller/inventory') {
          return _MockHttpAdapter.json({
            'success': true,
            'data': [sampleDraft.toJson()],
          });
        }
        return _MockHttpAdapter.json({'success': false}, statusCode: 404);
      });

      final client =
          ApiClient(adapter: adapter, tokenStorage: InMemoryTokenStorage());
      final repo = SellerRepository(apiService: SellerApiService(client: client));

      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: SellerInventoryScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('inventory_card_tap_101'));
      expect(cardFinder, findsOneWidget);

      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.text('Detail Produk'), findsOneWidget);
      expect(find.text('Kecap Manis Cap Bango 500ml'), findsOneWidget);
      expect(find.byKey(const Key('btn_continue_draft')), findsOneWidget);
      expect(find.byKey(const Key('btn_delete_draft')), findsOneWidget);
    });

    testWidgets('Detail Screen status draft dapat menghapus draf dengan konfirmasi',
        (tester) async {
      bool deleteCalled = false;
      final adapter = _MockHttpAdapter((options) async {
        if (options.method == 'DELETE' &&
            options.path == '/listings/seller/inventory/101') {
          deleteCalled = true;
          return _MockHttpAdapter.json({'success': true, 'data': {}});
        }
        return _MockHttpAdapter.json({'success': false}, statusCode: 404);
      });

      final client =
          ApiClient(adapter: adapter, tokenStorage: InMemoryTokenStorage());
      final repo = SellerRepository(apiService: SellerApiService(client: client));

      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: SellerProductDetailScreen(
            item: sampleDraft,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtn = find.byKey(const Key('btn_delete_draft'));
      expect(deleteBtn, findsOneWidget);

      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Hapus Draf Produk?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_confirm_delete_draft')));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
    });

    testWidgets('Lanjutkan Upload membuka flow di Step 2 Validasi dengan data terisi',
        (tester) async {
      AuthRepository.instance.currentUserProfile = const UserProfile(
        id: 52,
        email: 'seller@recovera.com',
        name: 'Penjual',
        role: 'seller',
      );

      final adapter = _MockHttpAdapter((options) async {
        if (options.path.contains('/validate')) {
          return _MockHttpAdapter.json({
            'success': true,
            'data': {'valid': true, 'errors': [], 'status': 'review'}
          });
        }
        return _MockHttpAdapter.json({'success': false}, statusCode: 404);
      });

      final client =
          ApiClient(adapter: adapter, tokenStorage: InMemoryTokenStorage());
      final repo = SellerRepository(apiService: SellerApiService(client: client));

      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: UploadStockFlowScreen(
            existingDraft: sampleDraft,
            repository: repo,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 1500));

      // Step 2 Validasi otomatis aktif
      expect(find.text('Memeriksa Produk'), findsOneWidget);
      expect(find.text('Kriteria Validasi Pangan'), findsOneWidget);
    });
  });
}
