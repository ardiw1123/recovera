import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';

/// Screen Splash Screen Recovera B2B
///
/// Menampilkan identitas visual logo Recovera di tengah layar dengan tagline
/// "Recover Value, Reduce Waste", serta inisialisasi sesi pengguna untuk
/// mengarahkan ke halaman Welcome (jika belum login) atau Home (jika sudah login).
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.autoNavigate = true,
    this.duration = const Duration(seconds: 2),
    this.onNavigate,
    this.checkAuth,
  });

  /// Menentukan apakah layar otomatis berpindah setelah durasi berakhir.
  /// Dapat dinonaktifkan untuk pengujian widget/unit test.
  final bool autoNavigate;

  /// Durasi tampilan splash sebelum navigasi.
  final Duration duration;

  /// Callback kustom saat navigasi terjadi (berguna untuk pengujian).
  final void Function(bool isAuthenticated)? onNavigate;

  /// Fungsi override untuk mengecek autentikasi (berguna untuk unit test tanpa platform channel).
  final Future<bool> Function()? checkAuth;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();

    if (widget.autoNavigate) {
      _startNavigationFlow();
    }
  }

  Future<void> _startNavigationFlow() async {
    // 1. Jalankan pengecekan sesi dan timer durasi secara konkuren
    final results = await Future.wait([
      _resolveAuthStatus(),
      Future.delayed(widget.duration),
    ]);

    if (!mounted) return;

    final isAuthenticated = results.first as bool;

    // 2. Berpindah ke rute yang sesuai
    if (widget.onNavigate != null) {
      widget.onNavigate!(isAuthenticated);
      return;
    }

    if (isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/welcome');
    }
  }

  Future<bool> _resolveAuthStatus() async {
    if (widget.checkAuth != null) {
      return widget.checkAuth!();
    }
    try {
      return await AuthRepository.instance.init();
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Recovera dari lib/assets/recovera-logo-raw.png
                  Image.asset(
                    'lib/assets/recovera-logo-raw.png',
                    key: const Key('splash_logo_image'),
                    width: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 18),
                  // Tagline slogan Recover Value, Reduce Waste
                  Text(
                    'Recover Value, Reduce Waste',
                    key: const Key('splash_tagline_text'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A4E8D),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
