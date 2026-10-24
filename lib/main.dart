import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Impor konfigurasi UI dan rute lokal Anda
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/navigation/app_navigator.dart';
import 'core/services/network_connectivity_service.dart';
import 'features/splash/screens/splash_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/seller/screens/seller_dashboard_screen.dart';
import 'features/seller/screens/upload_stock_flow_screen.dart';
import 'features/home/screens/product_detail_screen.dart';
import 'data/repositories/app_prefs_repository.dart';
import 'features/auth/screens/location_management_screen.dart';
import 'features/sky_balance/sky_balance_screen.dart';

Future<void> main() async {
  // 1. Pastikan binding Flutter terinisialisasi
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefsRepository.instance.init();
  await NetworkConnectivityService.instance.init();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 4. Atur warna System UI (Status bar transparan/biru, Navigation bar bawah putih)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.primary,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // 5. Jalankan UI Aplikasi
  runApp(const RecoveraApp());
}

class RecoveraApp extends StatelessWidget {
  const RecoveraApp({
    super.key,
    this.initialRoute = '/splash',
  });

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recovera B2B',
      debugShowCheckedModeBanner:
          false, // Menghilangkan pita "DEBUG" di pojok kanan atas
      theme: AppTheme.light, // Menerapkan tema warna dan tipografi global
      navigatorKey: AppNavigator.navigatorKey,
      scaffoldMessengerKey: AppNavigator.scaffoldMessengerKey,
      // Named routes — alur navigasi aplikasi
      initialRoute: initialRoute,
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/welcome': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const MainShell(),
        '/seller/dashboard': (_) => const SellerDashboardScreen(),
        '/seller/upload': (_) => const UploadStockFlowScreen(),
        '/product/detail': (_) => const ProductDetailScreen(),
        '/profile/location': (_) => const LocationManagementScreen(),
        '/sky-balance': (_) => const SkyBalanceScreen(),
      },
    );
  }
}
