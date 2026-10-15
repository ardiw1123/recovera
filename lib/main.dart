import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/shell/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Atur orientasi hanya potrait (mobile app)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Atur warna system UI (status bar biru, navigation bar putih)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.primary,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const RecoveraApp());
}

class RecoveraApp extends StatelessWidget {
  const RecoveraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recovera B2B',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Named routes — menghindari circular import antar screen
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const MainShell(),
      },
    );
  }
}
