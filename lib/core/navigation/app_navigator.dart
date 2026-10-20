import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/api_constants.dart';
import '../theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';

/// Service navigator & UI notification terpusat untuk alur autentikasi dan kedaluwarsa sesi.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static bool _isHandlingSessionExpired = false;

  /// Mengarahkan pengguna kembali ke halaman Login saat sesi berakhir
  /// dan menampilkan pemberitahuan bahwa sesi telah kedaluwarsa.
  static void handleSessionExpired({
    String message = ApiConstants.sessionExpiredMessage,
  }) {
    if (_isHandlingSessionExpired) return;
    _isHandlingSessionExpired = true;

    // Reset flag setelah 2 detik agar alur masa depan dapat menampilkan kembali jika relevan
    Future.delayed(const Duration(seconds: 2), () {
      _isHandlingSessionExpired = false;
    });

    // 1. Tampilkan notifikasi visual yang jelas kepada pengguna
    showSessionExpiredSnackBar(message);

    // 2. Arahkan pengguna ke layar Login dan bersihkan seluruh rute privat
    final navState = navigatorKey.currentState;
    if (navState != null) {
      navState.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
        arguments: {
          'session_expired': true,
          'message': message,
        },
      );
    }
  }

  /// Menampilkan SnackBar sesi berakhir dengan desain konsisten M3
  static void showSessionExpiredSnackBar(String message) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.timer_off_outlined,
              color: AppColors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Memverifikasi hak akses pengguna untuk fitur penjual (Seller-only safeguard).
  /// Menolak akun buyer dengan notifikasi visual SnackBar dan mengembalikan false.
  static bool verifySellerAccess({
    String message =
        'Akses ditolak: Akun pembeli tidak memiliki izin untuk mengakses alur kerja penjual.',
  }) {
    // Cek role via AuthRepository
    if (!AuthRepository.instance.isSeller) {
      showAccessDeniedSnackBar(message);
      return false;
    }
    return true;
  }

  /// Memverifikasi hak akses pengguna untuk fitur pembeli (Buyer-only safeguard).
  /// Menolak akun seller dengan notifikasi visual SnackBar dan mengembalikan false.
  static bool verifyBuyerAccess({
    String message =
        'Akses ditolak: Akun penjual tidak memiliki izin untuk mengakses fitur pembeli.',
  }) {
    // Cek role via AuthRepository
    if (AuthRepository.instance.isSeller) {
      showAccessDeniedSnackBar(message);
      return false;
    }
    return true;
  }

  /// Menampilkan SnackBar peringatan akses ditolak untuk akun yang tidak berwenang
  static void showAccessDeniedSnackBar(String message) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.gpp_bad_outlined,
              color: AppColors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
