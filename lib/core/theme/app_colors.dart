import 'package:flutter/material.dart';

/// ============================================================================
/// PUSAT PENGATURAN WARNA APLIKASI (DESIGN TOKENS)
/// ============================================================================
/// Untuk presentasi/demo, kamu bisa ganti warna seluruh aplikasi HANYA di file ini!
/// Tips Format Hex: Color(0xFF + 6 digit kode hex)
/// Contoh: Merah = Color(0xFFFF0000), Hijau = Color(0xFF10B981), Ungu = Color(0xFF7C3AED)
class AppColors {
  AppColors._();

  // ─── [GANTI_WARNA_UTAMA] Palet Warna Primer & Branding ───────────────────────
  // Ubah warna di bawah ini untuk mengubah warna dominan (Header, Tombol Utama, dll.)
  
  /// Warna Utama (Header Atas, Tombol Login, Icon Aktif) -> Default: Biru Recovera
  static const Color primary = Color(0xFF0077B6);

  /// Warna Primer Gelap (Gradient Bawah Header / State Ditekan)
  static const Color primaryDark = Color(0xFF005F92);

  /// Warna Primer Terang (Gradient Atas Header)
  static const Color primaryLight = Color(0xFF006CA7);

  /// Warna Sekunder (Elemen pendukung, badge, aksen sekunder)
  static const Color secondary = Color(0xFF00B4D8);

  /// Warna Aksen Terang (Lapisan gelombang/wave backdrop header)
  static const Color accent = Color(0xFF90E0EF);

  // ─── [GANTI_WARNA_TEKS] Teks & Background Utama ──────────────────────────────
  
  /// Warna Judul / Heading Utama (Welcome back, Profil Saya, Nama Produk) -> Default: Navy Gelap
  static const Color darkNavy = Color(0xFF03045E);

  /// Warna Teks Subtitle / Deskripsi / Hint / Label Form -> Default: Abu-abu Slate
  static const Color slateText = Color(0xFF64748B);

  /// Warna Background Halaman (Canvas Layar Belakang) -> Default: Putih Kebiruan Lembut
  static const Color canvasBg = Color(0xFFF8FAFC);

  /// Warna Putih Murni (Card, Modal Sheet, Teks di atas tombol biru)
  static const Color white = Color(0xFFFFFFFF);

  // ─── [GANTI_WARNA_STATUS] Warna Notifikasi / Status ──────────────────────────
  
  /// Status Sukses (Badge Selesai, Centang Hijau, Notif Berhasil)
  static const Color success = Color(0xFF10B981);       // emerald-500
  static const Color successBg = Color(0xFFECFDF5);     // background badge hijau
  static const Color successBorder = Color(0xFF6EE7B7); // border badge hijau

  /// Status Gagal / Bahaya / Error (Snack bar error, validasi gagal, tombol hapus)
  static const Color error = Color(0xFFEF4444);          // red-500

  // ─── [GANTI_WARNA_KOMPONEN] Border & Input Field ─────────────────────────────
  
  /// Garis Tepi / Border Input Box & Card
  static const Color border = Color(0xFFE2E8F0);         // slate-200

  /// Background Kolom Input Form
  static const Color inputBg = Color(0xFFF8FAFC);        // slate-50

  /// Warna Efek Bayangan / Shadow Tombol
  static const Color shadow = Color(0xFF0077B6);
}
