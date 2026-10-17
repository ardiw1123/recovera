import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/core/theme/app_theme.dart';
import 'package:recovera/features/splash/screens/splash_screen.dart';
import 'package:recovera/features/auth/screens/welcome_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplashScreen Widget Tests', () {
    testWidgets('menampilkan logo Recovera dan tagline slogan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const SplashScreen(autoNavigate: false),
        ),
      );

      // Pastikan logo recovera-logo-raw.png terpasang
      expect(find.byKey(const Key('splash_logo_image')), findsOneWidget);

      // Pastikan teks tagline "Recover Value, Reduce Waste" muncul
      expect(find.byKey(const Key('splash_tagline_text')), findsOneWidget);
      expect(find.text('Recover Value, Reduce Waste'), findsOneWidget);
    });

    testWidgets('navigasi otomatis memanggil callback onNavigate dengan durasi yang ditentukan',
        (tester) async {
      bool? navigatedAuth;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SplashScreen(
            autoNavigate: true,
            duration: const Duration(milliseconds: 200),
            checkAuth: () async => false,
            onNavigate: (isAuth) {
              navigatedAuth = isAuth;
            },
          ),
        ),
      );

      expect(navigatedAuth, isNull);

      // Majukan timer melampaui durasi splash
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(navigatedAuth, isNotNull);
      expect(navigatedAuth, isFalse);
    });
  });

  group('WelcomeScreen Widget Tests', () {
    testWidgets('menampilkan logo horizontal, kartu B2B, teks judul, tombol, dan link login',
        (tester) async {
      // Set viewport agar cukup menampung konten layar (misal iPhone 15 Pro: 393 x 852)
      tester.view.physicalSize = const Size(393 * 3.0, 852 * 3.0);
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const WelcomeScreen(),
        ),
      );

      // 1. Logo Horizontal
      expect(find.byKey(const Key('welcome_logo_image')), findsOneWidget);

      // 2. Kartu B2B Matching
      expect(find.text('Stok Berlebih'), findsOneWidget);
      expect(find.text('Distributor Pangan'), findsOneWidget);
      expect(find.text('Validasi AI'), findsOneWidget);

      expect(find.text('Smart Match'), findsOneWidget);
      expect(find.text('Harga Rekomendasi'), findsOneWidget);

      expect(find.text('Pembeli Bisnis'), findsOneWidget);
      expect(find.text('Resto, Hotel,\nUMKM'), findsOneWidget);
      expect(find.text('Terverifikasi'), findsOneWidget);

      // 3. Tiga pilar nilai
      expect(find.text('Kualitas Teruji'), findsOneWidget);
      expect(find.text('Logistik Cepat'), findsOneWidget);
      expect(find.text('Zero Waste'), findsOneWidget);

      // 4. Headline & Deskripsi
      expect(find.byKey(const Key('welcome_headline_text')), findsOneWidget);
      expect(
        find.text('Pulihkan Nilai Stok.\nKurangi Food Waste.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('welcome_description_text')), findsOneWidget);

      // 5. Tombol Aksi
      expect(find.byKey(const Key('btn_mulai_sekarang')), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);
      expect(find.byKey(const Key('link_login')), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('menekan "Mulai Sekarang" mengarahkan rute ke /register', (tester) async {
      tester.view.physicalSize = const Size(393 * 3.0, 852 * 3.0);
      tester.view.devicePixelRatio = 3.0;

      String? currentRoute;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          initialRoute: '/welcome',
          routes: {
            '/welcome': (_) => const WelcomeScreen(),
            '/register': (_) {
              currentRoute = '/register';
              return const Scaffold(body: Text('Register Screen Mock'));
            },
            '/login': (_) {
              currentRoute = '/login';
              return const Scaffold(body: Text('Login Screen Mock'));
            },
          },
        ),
      );

      final btn = find.byKey(const Key('btn_mulai_sekarang'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(currentRoute, equals('/register'));
      expect(find.text('Register Screen Mock'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('menekan "Login" mengarahkan rute ke /login', (tester) async {
      tester.view.physicalSize = const Size(393 * 3.0, 852 * 3.0);
      tester.view.devicePixelRatio = 3.0;

      String? currentRoute;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          initialRoute: '/welcome',
          routes: {
            '/welcome': (_) => const WelcomeScreen(),
            '/register': (_) {
              currentRoute = '/register';
              return const Scaffold(body: Text('Register Screen Mock'));
            },
            '/login': (_) {
              currentRoute = '/login';
              return const Scaffold(body: Text('Login Screen Mock'));
            },
          },
        ),
      );

      final link = find.byKey(const Key('link_login'));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(currentRoute, equals('/login'));
      expect(find.text('Login Screen Mock'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('tata letak responsif pada berbagai dimensi layar tanpa overflow',
        (tester) async {
      // 1. Uji layar kecil (320x568 - iPhone SE generasi awal)
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const WelcomeScreen(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('welcome_headline_text')), findsOneWidget);

      // 2. Uji layar tablet/desktop (800x1200)
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const WelcomeScreen(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('btn_mulai_sekarang')), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
