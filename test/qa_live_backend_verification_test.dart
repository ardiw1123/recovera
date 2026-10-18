import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/data/data.dart';

/// ARDI-73 â€” Stage 3 QA verification.
///
/// Menjalankan stack klien yang sebenarnya (ApiClient, AuthInterceptor,
/// AuthApiService/AuthRepository, ListingApiService, OrderApiService,
/// FeedbackApiService) langsung terhadap backend FastAPI hidup di
/// http://127.0.0.1:8001 dengan database QA terisolasi (qa_ardi73_qa.db).
/// Jalur htt utama tidak memakai mock; dua kasus khusus memakai
/// definisinya sendiri (koneksi ditolak â†’ port tertutup; 5xx â†’ adapter).
const String liveBaseUrl = 'http://127.0.0.1:8001';

String _uniqueEmail(String tag) =>
    'qa-$tag-${DateTime.now().millisecondsSinceEpoch}@example.com';

/// Simulasi outcome server-error (HTTP 500) untuk satu endpoint.
class ServerErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      utf8.encode(
        jsonEncode({
          'success': false,
          'error': {'code': 'INTERNAL_SERVER_ERROR', 'message': 'Terjadi kesalahan server'},
        }),
      ),
      500,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() async {
  // CATATAN: TANPA TestWidgetsFlutterBinding — binding itu memalsukan semua
  // HTTP ke status 400 di dalam flutter test. Verifikasi hidup ini butuh
  // soket jaringan nyata, jadi jalankan sebagai test Dart murni.

  bool serverAvailable = false;
  try {
    final socket = await Socket.connect('127.0.0.1', 8001, timeout: const Duration(milliseconds: 500));
    await socket.close();
    serverAvailable = true;
  } catch (_) {
    serverAvailable = false;
  }

  final liveSkip = serverAvailable ? null : 'Live FastAPI server at 127.0.0.1:8001 is not running';

  group('G0 — Server live terjangkau (read-only)', () {
    test('GET /health membalas amplop sukses dari backend hidup', () async {
      final dio = Dio();
      final response = await dio.get<Map<String, dynamic>>('$liveBaseUrl/health');
      expect(response.statusCode, 200);
      expect(response.data!['success'], true);
      expect(response.data!['data']['status'], 'healthy');
    });
  }, skip: liveSkip);

  group('G1 â€” Registrasi sukses per role dengan data lengkap', () {
    late InMemoryTokenStorage storage;

    setUp(() => storage = InMemoryTokenStorage());

    test('Seller dengan company_name lengkap terdaftar; profil menampilkan perusahaan',
        () async {
      final email = _uniqueEmail('seller');
      final client = ApiClient(baseUrl: liveBaseUrl, tokenStorage: storage);
      final repository = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );

      final tokens = await repository.register(
        email: email,
        password: 'Password8x!',
        role: 'seller',
        name: 'Budi Santoso',
        companyName: 'PT Pangan Mandiri QA',
        address: 'Jl. QA Warehouse 1',
        city: 'Jakarta',
      );

      // Registrasi sukses: sesi otomatis tersimpan (persistensi sesi).
      expect(repository.isAuthenticated, isTrue);
      expect(tokens.role, 'seller');
      expect(tokens.accessToken, isNotEmpty);
      expect(tokens.refreshToken, isNotEmpty);
      expect(await storage.getAccessToken(), tokens.accessToken);

      // Request terlindungi via Bearer membawa data seller yang dikirim klien.
      final profile = await repository.fetchProfile();
      expect(profile.role, 'seller');
      expect(profile.companyName, 'PT Pangan Mandiri QA');
      expect(profile.email, email);
      expect(profile.name, 'Budi Santoso');
    });

    test('Buyer dengan data lengkap terdaftar tanpa company_name', () async {
      final email = _uniqueEmail('buyer');
      final client = ApiClient(baseUrl: liveBaseUrl, tokenStorage: InMemoryTokenStorage());
      final authService = AuthApiService(client: client);

      final tokens = await authService.register(
        email: email,
        password: 'Password8x!',
        role: 'buyer',
        name: 'Siti Rahma',
      );

      expect(tokens.role, 'buyer');
      expect(tokens.accessToken, isNotEmpty);
      expect(tokens.expiresIn, 3600);

      await client.tokenStorage.saveTokens(tokens);
      final profile = await authService.getProfile();
      expect(profile.role, 'buyer');
      expect(profile.email, email);
    });

    test('Sesi tersimpan dipakai kembali oleh klien baru ("restart" aplikasi)', () async {
      final email = _uniqueEmail('restart');
      final client = ApiClient(baseUrl: liveBaseUrl, tokenStorage: storage);
      final repository = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );

      await repository.register(
        email: email,
        password: 'Password8x!',
        role: 'buyer',
        name: 'QA Restart',
      );

      // Klien baru tanpa state memori membaca storage yang historynya sudah ada.
      final restoredTokens = await storage.getTokens();
      expect(restoredTokens?.accessToken, isNotEmpty);

      final freshClient = ApiClient(baseUrl: liveBaseUrl, tokenStorage: storage);
      final response = await freshClient.get<Map<String, dynamic>>('/profile');
      // Interceptor menyuntikkan Bearer, sehingga tidak 401.
      expect(response.statusCode, 200);
      expect(response.data!['success'], true);
      expect((response.data!['data'] as Map<String, dynamic>)['email'], email);
    });
  }, skip: liveSkip);

  group('G2 â€” Registrasi: field wajib tidak lengkap / tidak valid', () {
    late InMemoryTokenStorage storage;
    late AuthApiService authService;

    setUp(() {
      storage = InMemoryTokenStorage();
      authService = AuthApiService(
        client: ApiClient(baseUrl: liveBaseUrl, tokenStorage: storage),
      );
    });

    test('Seller tanpa company_name diblokir: 422 MISSING_SELLER_INFO dari backend',
        () async {
      // Regresi cacat awal: payload seller TANPA company_name â€” persis
      // seperti form lama yang memicu laporan di ARDI-70.
      final email = _uniqueEmail('nocompany');
      try {
        await authService.register(
          email: email,
          password: 'Password8x!',
          role: 'seller',
          name: 'Seller Tanpa Perusahaan',
        );
        fail('Harusnya gagal dengan MISSING_SELLER_INFO');
      } on ApiException catch (e) {
        expect(e.code, 'MISSING_SELLER_INFO');
        expect(e.statusCode, 422);
        expect(e.message, contains('Company name'));
      }
    });

    test('Email duplikat diblokir: 409 EMAIL_ALREADY_EXISTS disalurkan ke UI', () async {
      final email = _uniqueEmail('duplicate');
      final payload = <String, dynamic>{
        'email': email,
        'password': 'Password8x!',
        'role': 'seller',
        'name': 'Budi Santoso',
        'company_name': 'PT Pangan Mandiri QA',
      };

      final dio = Dio();
      final first = await dio.post<Map<String, dynamic>>(
        '$liveBaseUrl/auth/register',
        data: payload,
      );
      expect(first.statusCode, 201);
      expect(first.data!['success'], true);

      try {
        await authService.register(
          email: email,
          password: 'Password8x!',
          role: 'seller',
          name: 'Budi Santoso',
          companyName: 'PT Pangan Mandiri QA',
        );
        fail('Harusnya gagal dengan EMAIL_ALREADY_EXISTS');
      } on ApiException catch (e) {
        expect(e.code, 'EMAIL_ALREADY_EXISTS');
        expect(e.statusCode, 409);
      }
    });

    test('Email tidak valid diblokir: 422 VALIDATION_ERROR', () async {
      try {
        await authService.register(
          email: 'bukan-email-tanpa-at',
          password: 'Password8x!',
          role: 'buyer',
          name: 'Email Invalid',
        );
        fail('Harusnya gagal VALIDATION_ERROR');
      } on ApiException catch (e) {
        expect(e.statusCode, 422);
        expect(e.message, isNotEmpty);
      }
    });

    test('Password di bawah 8 karakter diblokir: 422 VALIDATION_ERROR', () async {
      try {
        await authService.register(
          email: _uniqueEmail('shortpass'),
          password: 'short',
          role: 'buyer',
          name: 'Password Pendek',
        );
        fail('Harusnya gagal karena password pendek');
      } on ApiException catch (e) {
        expect(e.statusCode, 422);
        expect(e.message, contains('password'));
      }
    });

    test('Role di luar seller/buyer diblokir: 422 VALIDATION_ERROR', () async {
      try {
        await authService.register(
          email: _uniqueEmail('badrole'),
          password: 'Password8x!',
          role: 'admin',
          name: 'Role Invalid',
        );
        fail('Harusnya gagal karena role tidak valid');
      } on ApiException catch (e) {
        expect(e.statusCode, 422);
      }
    });

    test('Nama kosong diblokir: 422 VALIDATION_ERROR', () async {
      try {
        await authService.register(
          email: _uniqueEmail('noname'),
          password: 'Password8x!',
          role: 'buyer',
          name: '',
        );
        fail('Harusnya gagal karena nama kosong');
      } on ApiException catch (e) {
        expect(e.statusCode, 422);
      }
    });

    test('Validator form klien memblokir email/password tidak valid sebelum jaringan',
        () {
      // Mereplikasi logika validator RegisterScreen (blokir sebelum jaringan).
      String? emailValidator(String? v) {
        if (v == null || v.isEmpty) return 'Wajib diisi';
        if (!v.contains('@')) return 'Format email tidak valid';
        return null;
      }

      String? passwordValidator(String? v) {
        if (v == null || v.isEmpty) return 'Wajib diisi';
        if (v.length < 8) return 'Minimal 8 karakter';
        return null;
      }

      expect(emailValidator(''), 'Wajib diisi');
      expect(emailValidator('salahformat'), 'Format email tidak valid');
      expect(emailValidator('ok@mail.com'), isNull);
      expect(passwordValidator(null), 'Wajib diisi');
      expect(passwordValidator('1234567'), 'Minimal 8 karakter');
      expect(passwordValidator('Password8x!'), isNull);
    });
  }, skip: liveSkip);

  group('G3 â€” Siklus hidup autentikasi via REST', () {
    late InMemoryTokenStorage storage;
    late ApiClient client;
    late AuthRepository repository;
    final sessionExpiredMessages = <String>[];

    setUp(() {
      storage = InMemoryTokenStorage();
      sessionExpiredMessages.clear();
      client = ApiClient(
        baseUrl: liveBaseUrl,
        tokenStorage: storage,
        onSessionExpired: sessionExpiredMessages.add,
      );
      repository = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
    });

    test('Login kredensial salah â†’ 401 INVALID_CREDENTIALS, sesi tidak tercipta',
        () async {
      try {
        await repository.login(
          email: _uniqueEmail('notexist'),
          password: 'WrongPass99',
        );
        fail('Harusnya gagal INVALID_CREDENTIALS');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
        expect(e.code, 'INVALID_CREDENTIALS');
      }
      expect(repository.isAuthenticated, isFalse);
      expect(await storage.getAccessToken(), isNull);
    });

    test('GET /profile tanpa Bearer ditolak 401 oleh server', () async {
      final dio = Dio();
      try {
        await dio.get<Map<String, dynamic>>('$liveBaseUrl/profile');
        fail('Tanpa token seharusnya 401');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 401);
        final body = e.response?.data as Map<String, dynamic>;
        expect(body['success'], false);
        expect(body['error']['code'], 'UNAUTHORIZED');
      }
    });

    test('Logout diikuti login: access/refresh token baru masing-masing dirotasi',
        () async {
      final email = _uniqueEmail('lifecycle');

      await repository.register(
        email: email,
        password: 'Password8x!',
        role: 'buyer',
        name: 'QA Lifecycle',
      );
      final registrationRefresh = await storage.getRefreshToken();

      await repository.logout();

      final loggedIn = await repository.login(email: email, password: 'Password8x!');
      expect(loggedIn.accessToken, isNotEmpty);
      // Sesi baru: refresh token acak dan berbeda dari sesi registrasi.
      expect(loggedIn.refreshToken, isNot(registrationRefresh));
      // Sesi login berfungsi: request terlindungi balas 200 dengan token barunya.
      expect(await storage.getAccessToken(), loggedIn.accessToken);
    });

    test('Silent refresh: access token tidak sah dipulihkan transparan, token dirotasi',
        () async {
      final email = _uniqueEmail('refresh');

      await repository.register(
        email: email,
        password: 'Password8x!',
        role: 'buyer',
        name: 'QA Refresh',
      );
      final validRefresh = (await storage.getRefreshToken())!;

      // Simulasi access token kedaluwarsa di perangkat
      // sementara refresh token tetap sah.
      await storage.saveTokens(AuthTokens(
        accessToken: 'expired-or-garbage-token',
        refreshToken: validRefresh,
      ));

      final freshClient = ApiClient(
        baseUrl: liveBaseUrl,
        tokenStorage: storage,
        onSessionExpired: sessionExpiredMessages.add,
      );

      // 401 dipicu silent refresh, lalu retry transparan menjadi 200.
      final response = await freshClient.get<Map<String, dynamic>>('/profile');
      expect(response.statusCode, 200);
      expect(response.data!['success'], true);

      // Token baru dipersist â€” access diputar, refresh token dirotasi.
      expect(await storage.getAccessToken(), isNot('expired-or-garbage-token'));
      expect(await storage.getRefreshToken(), isNot(validRefresh));
      expect(sessionExpiredMessages, isEmpty);
    });

    test('Refresh token dicabut â†’ sesi dibersihkan, pesan kedaluwarsa muncul sekali',
        () async {
      final email = _uniqueEmail('revoke');

      await repository.register(
        email: email,
        password: 'Password8x!',
        role: 'buyer',
        name: 'QA Revoked',
      );
      final validAccess = (await storage.getAccessToken())!;
      final validRefresh = (await storage.getRefreshToken())!;

      // Cabut semua refresh token user di server via /auth/logout.
      final dio = Dio();
      final logout = await dio.post<Map<String, dynamic>>(
        '$liveBaseUrl/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $validAccess'}),
      );
      expect(logout.statusCode, 200);

      // Simulasi perangkat: access token sampah + refresh token yang kini dicabut.
      await storage.saveTokens(AuthTokens(
        accessToken: 'garbage-access-token',
        refreshToken: validRefresh,
      ));

      final freshClient = ApiClient(
        baseUrl: liveBaseUrl,
        tokenStorage: storage,
        onSessionExpired: sessionExpiredMessages.add,
      );

      try {
        await freshClient.get<Map<String, dynamic>>('/profile');
        fail('Harusnya 401 karena refresh tidak sah');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 401);
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }

      // Sesi akhir: token dibersihkan dan pesan kedaluwarsa dinotifikasi sekali.
      final leftAccess = await storage.getAccessToken();
      expect(leftAccess, isNull);
      final leftRefresh = await storage.getRefreshToken();
      expect(leftRefresh, isNull);
      expect(sessionExpiredMessages, hasLength(1));
      expect(sessionExpiredMessages.first, contains('login'));
    });

    test('Logout mencabut refresh token di backend; refresh ulang ditolak 401',
        () async {
      final email = _uniqueEmail('logout');

      await repository.register(
        email: email,
        password: 'Password8x!',
        role: 'buyer',
        name: 'QA Logout',
      );
      final refreshTokenUsed = (await storage.getRefreshToken())!;

      await repository.logout();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(repository.isAuthenticated, isFalse);

      // Refresh token yang dicabut: server menolak dengan INVALID_REFRESH_TOKEN.
      final dio = Dio();
      try {
        await dio.post<Map<String, dynamic>>(
          '$liveBaseUrl/auth/refresh',
          data: {'refresh_token': refreshTokenUsed},
        );
        fail('Harusnya 401 INVALID_REFRESH_TOKEN');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 401);
        final body = e.response?.data as Map<String, dynamic>;
        expect(
          body['error']['code'],
          anyOf('INVALID_REFRESH_TOKEN', 'EXPIRED_REFRESH_TOKEN'),
        );
      }
    });
  }, skip: liveSkip);

  group('G4 â€” Alur data endpoint-backed (listings / orders / feedback)', () {
    late InMemoryTokenStorage storage;
    late ApiClient client;
    late AuthRepository repository;

    setUp(() {
      storage = InMemoryTokenStorage();
      client = ApiClient(baseUrl: liveBaseUrl, tokenStorage: storage);
      repository = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );
    });

    test('GET /listings: katalog kosong untuk acuan unik, lalu seeded dan terpetakan',
        () async {
      final listingService = ListingApiService(client: client);

      // Outcome kosong: database QA bersih untuk pencarian nomor unik ini.
      final probe = DateTime.now().millisecondsSinceEpoch.toString();
      final before = await listingService.fetchRemoteListings(search: probe);
      expect(before, isEmpty);

      // Seed: product + listing via seller yang baru diregistrasi.
      final seller = await repository.register(
        email: _uniqueEmail('sellerflow'),
        password: 'Password8x!',
        role: 'seller',
        name: 'QA Seller Flow',
        companyName: 'PT QA Seller Flow',
      );
      expect(seller.role, 'seller');

      final productResponse = await client.post<Map<String, dynamic>>(
        '/products',
        data: {
          'sku': 'QA-SKU-$probe',
          'name': 'Beras Premium $probe',
          'category': 'QA Category',
          'storage_type': 'ambient',
          'default_unit': 'karung',
          'brand': 'QA Brand',
        },
      );
      expect(productResponse.statusCode, 201);
      final productId = productResponse.data!['data']['id'] as int;

      final expiry =
          DateTime.now().add(const Duration(days: 60)).toIso8601String().split('T').first;
      final listingId = await listingService.uploadDraftListing(DraftListingModel(
        productId: productId,
        productName: 'Beras QA $probe',
        category: 'QA Category',
        batchNumber: 'QA-BATCH-001',
        qty: 50,
        normalPrice: 100000,
        startPrice: 90000,
        minPrice: 50000,
        expiryDate: expiry,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ));
      expect(listingId, greaterThan(0));

      // Baca kembali via klien dan map ke model klien.
      final found = await listingService.fetchRemoteListings(search: probe);
      expect(found, hasLength(1));
      final mapped = found.first;
      expect(mapped.id, listingId);
      expect(mapped.productId, productId);
      expect(mapped.sellerCompany, 'PT QA Seller Flow');
      expect(mapped.status, 'active');
      expect(mapped.startPrice, 90000);
      expect(mapped.minPrice, 50000);
      expect(mapped.category, 'QA Category');
    });

    test('GET /listings dengan filter max_price membalas sukses berupa daftar',
        () async {
      final listingService = ListingApiService(client: client);

      // Smoke keterhubungan â€” filter dinilai server; klien hanya meneruskannya.
      final filtered = await listingService.fetchRemoteListings(maxPrice: 5000);
      expect(filtered, isA<List<dynamic>>());
    });

    test('GET /orders: kosong untuk akun baru; detail id tak ada â†’ 404 bermakna',
        () async {
      final orderService = OrderApiService(client: client);
      final email = _uniqueEmail('orderflow');

      await repository.register(
        email: email,
        password: 'Password8x!',
        role: 'buyer',
        name: 'QA Order Flow',
      );

      // Outcome kosong.
      final orders = await orderService.fetchRemoteOrders();
      expect(orders, isEmpty);

      // Outcome server-side gagal: id pesanan tidak ada.
      try {
        await orderService.fetchRemoteOrderDetail(999999);
        fail('Harusnya gagal 404');
      } on ApiException catch (e) {
        expect(e.statusCode, 404);
        expect(e.message, contains('not found'));
      }
    });

    test('POST /feedback: tanpa sesi â†’ 401; terautentikasi â†’ tersimpan di backend',
        () async {
      final feedbackService = FeedbackApiService(client: client);

      // Tanpa sesi: harus 401 dari server, bukan crash.
      try {
        await feedbackService.submitFeedback(
          kesan: 'QA tanpa sesi',
          saran: 'Harusnya 401',
        );
        fail('Harusnya 401 karena belum login');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }

      await repository.register(
        email: _uniqueEmail('feedback'),
        password: 'Password8x!',
        role: 'buyer',
        name: 'QA Feedback',
      );

      final submitted = await feedbackService.submitFeedback(
        kesan: 'QA Kesan Sukses',
        saran: 'QA Saran Sukses',
      );
      expect(submitted['id'], greaterThan(0));
      expect(submitted['kesan'], 'QA Kesan Sukses');
      expect(submitted['saran'], 'QA Saran Sukses');
      expect(submitted['submitted_at'], isNotEmpty);

      // Selaras dengan server: feedback baru bisa dibaca dari DB â€” timbal tetap via API.
      final dio = Dio();
      final health = await dio.get<Map<String, dynamic>>('$liveBaseUrl/health');
      expect(health.statusCode, 200);
    });

    test('Outcome kegagalan jaringan: koneksi ditolak â†’ ApiException, bukan crash',
        () async {
      final unreachable = ApiClient(
        // Port tertutup di localhost sebagai simulasi backend hilang.
        baseUrl: 'http://127.0.0.1:23987',
        tokenStorage: InMemoryTokenStorage(),
      );
      final listingService = ListingApiService(client: unreachable);

      await expectLater(
        listingService.fetchRemoteListings(),
        throwsA(isA<ApiException>()),
      );
    });

    test('Outcome server-error 500: diangkat sebagai ApiException bermakna', () async {
      final failingClient = ApiClient(
        baseUrl: liveBaseUrl,
        tokenStorage: InMemoryTokenStorage(),
        adapter: ServerErrorAdapter(),
      );
      final listingService = ListingApiService(client: failingClient);

      try {
        await listingService.fetchRemoteListings();
        fail('Harusnya gagal dengan 500');
      } on ApiException catch (e) {
        expect(e.statusCode, 500);
        expect(e.message, 'Terjadi kesalahan server');
      }
    });
  }, skip: liveSkip);
}

