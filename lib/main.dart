import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Impor konfigurasi UI dan rute lokal Anda
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/navigation/app_navigator.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/shell/main_shell.dart';

Future<void> main() async {
  // 1. Pastikan binding Flutter terinisialisasi
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 4. Atur warna System UI (Status bar biru, Navigation bar bawah putih)
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
  const RecoveraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recovera B2B',
      debugShowCheckedModeBanner:
          false, // Menghilangkan pita "DEBUG" di pojok kanan atas
      theme: AppTheme.light, // Menerapkan tema warna dan tipografi global
      navigatorKey: AppNavigator.navigatorKey,
      scaffoldMessengerKey: AppNavigator.scaffoldMessengerKey,
      // Named routes — menghindari circular import antar screen
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const MainShell(),
      },
    );
  }
}
