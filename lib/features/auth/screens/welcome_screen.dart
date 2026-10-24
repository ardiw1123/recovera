import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Screen Welcome Screen B2B Recovera
///
/// Berisi identitas brand, visual interaktif pencocokan stok B2B (Smart Match),
/// proposisi nilai (Kurangi Food Waste & Pulihkan Nilai Stok),
/// tombol aksi utama "Mulai Sekarang" dan navigasi ke halaman Login.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ─── Bagian Atas: Logo & Kartu Value Proposition ───
                            Column(
                              children: [
                                const SizedBox(height: 18),
                                // Logo Recovera Horizontal
                                Image.asset(
                                  'lib/assets/recovera-logo-horizontal.png',
                                  key: const Key('welcome_logo_image'),
                                  height: 32,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 24),

                                // Kartu Proposisi Nilai Ekosistem B2B
                                const _B2BMatchingCard(),
                              ],
                            ),

                            // ─── Bagian Bawah: Headline, Keterangan & Aksi ──────
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  // Headline Utama
                                  Text(
                                    'Pulihkan Nilai Stok.\nKurangi Food Waste.',
                                    key: const Key('welcome_headline_text'),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.darkNavy,
                                      height: 1.25,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Deskripsi Solusi
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'Platform B2B untuk menghubungkan kelebihan stok pangan dengan pembeli yang tepat.',
                                      key: const Key('welcome_description_text'),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF5A6B82),
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Tombol Aksi Utama: "Mulai Sekarang"
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      key: const Key('btn_mulai_sekarang'),
                                      onPressed: () {
                                        Navigator.of(context).pushNamed('/register');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: AppColors.white,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        'Mulai Sekarang',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Footer: Navigasi ke Login
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Sudah punya akun? ',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF334155),
                                        ),
                                      ),
                                      GestureDetector(
                                        key: const Key('link_login'),
                                        onTap: () {
                                          Navigator.of(context).pushNamed('/login');
                                        },
                                        child: Text(
                                          'Login',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                            decoration: TextDecoration.underline,
                                            decorationColor: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Kartu Visual Pencocokan Stok B2B (Smart Match Ecosystem)
class _B2BMatchingCard extends StatelessWidget {
  const _B2BMatchingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0077B6).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row Utama: Distributor Pangan ─── Smart Match ─── Pembeli Bisnis
          const Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Kolom Kiri: Distributor (Stok Berlebih)
              Expanded(
                flex: 11,
                child: _RoleCard(
                  title: 'Stok Berlebih',
                  subtitle: 'Distributor Pangan',
                  tagText: 'Validasi AI',
                  tagTextColor: Color(0xFFD97706),
                  tagBorderColor: Color(0xFFFCD34D),
                  tagBgColor: Color(0xFFFFFBEB),
                  iconBgColor: Color(0xFFE0F7FA),
                  icon: CustomPaint(
                    size: Size(22, 22),
                    painter: IsometricCubePainter(
                      color: Color(0xFF0097A7),
                      strokeWidth: 2.0,
                    ),
                  ),
                ),
              ),

              // Kolom Tengah: Smart Match & Pipeline
              Expanded(
                flex: 10,
                child: _SmartMatchCenterColumn(),
              ),

              // Kolom Kanan: Pembeli Bisnis (Resto, Hotel, UMKM)
              Expanded(
                flex: 11,
                child: _RoleCard(
                  title: 'Pembeli Bisnis',
                  subtitle: 'Resto, Hotel,\nUMKM',
                  tagText: 'Terverifikasi',
                  tagTextColor: Color(0xFF059669),
                  tagBorderColor: Color(0xFF6EE7B7),
                  tagBgColor: Color(0xFFECFDF5),
                  iconBgColor: Color(0xFFECFDF5),
                  icon: CustomPaint(
                    size: Size(22, 22),
                    painter: StorefrontPainter(
                      color: Color(0xFF10B981),
                      strokeWidth: 2.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row Bawah: 3 Pilar Nilai (Kualitas Teruji, Logistik Cepat, Zero Waste)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PillarPill(
                    dotColor: Color(0xFF10B981),
                    label: 'Kualitas Teruji',
                  ),
                  SizedBox(width: 12),
                  _PillarPill(
                    dotColor: Color(0xFF0284C7),
                    label: 'Logistik Cepat',
                  ),
                  SizedBox(width: 12),
                  _PillarPill(
                    dotColor: Color(0xFF06B6D4),
                    label: 'Zero Waste',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sub-kartu peranan (Stok Berlebih / Pembeli Bisnis)
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.tagText,
    required this.tagTextColor,
    required this.tagBorderColor,
    required this.tagBgColor,
    required this.iconBgColor,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String tagText;
  final Color tagTextColor;
  final Color tagBorderColor;
  final Color tagBgColor;
  final Color iconBgColor;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon Container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(height: 8),

          // Judul
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.darkNavy,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Subjudul
          SizedBox(
            height: 28,
            child: Center(
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.slateText,
                  height: 1.15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Tag Status/Badge
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: tagBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: tagBorderColor,
                  width: 1.0,
                ),
              ),
              child: Text(
                tagText,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: tagTextColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kolom Tengah: Smart Match & Visualisasi Harga Rekomendasi
class _SmartMatchCenterColumn extends StatelessWidget {
  const _SmartMatchCenterColumn();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Badge "Smart Match" dengan ikon petir
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Smart Match',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Garis konektor visual: Dashed ──●──▶
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: CustomPaint(
              size: Size(76, 14),
              painter: SmartMatchConnectorPainter(),
            ),
          ),
          const SizedBox(height: 6),

          // Teks "Harga Rekomendasi"
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Harga Rekomendasi',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0284C7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Item Pilar Nilai dengan titik indikator warna
class _PillarPill extends StatelessWidget {
  const _PillarPill({
    required this.dotColor,
    required this.label,
  });

  final Color dotColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

/// CustomPainter untuk Ikon Kubus Isometrik (Stok Berlebih)
class IsometricCubePainter extends CustomPainter {
  const IsometricCubePainter({
    required this.color,
    this.strokeWidth = 2.0,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) * 0.44;

    final dx = r * 0.866; // cos(30 deg)
    final dy = r * 0.5;   // sin(30 deg)

    final c = Offset(cx, cy);
    final pTop = Offset(cx, cy - r);
    final pTopRight = Offset(cx + dx, cy - dy);
    final pBottomRight = Offset(cx + dx, cy + dy);
    final pBottom = Offset(cx, cy + r);
    final pBottomLeft = Offset(cx - dx, cy + dy);
    final pTopLeft = Offset(cx - dx, cy - dy);

    // Garis luar hexagon isometrik
    final outerPath = Path()
      ..moveTo(pTop.dx, pTop.dy)
      ..lineTo(pTopRight.dx, pTopRight.dy)
      ..lineTo(pBottomRight.dx, pBottomRight.dy)
      ..lineTo(pBottom.dx, pBottom.dy)
      ..lineTo(pBottomLeft.dx, pBottomLeft.dy)
      ..lineTo(pTopLeft.dx, pTopLeft.dy)
      ..close();

    canvas.drawPath(outerPath, paint);

    // Garis sambungan internal dari titik pusat
    canvas.drawLine(c, pTopLeft, paint);
    canvas.drawLine(c, pTopRight, paint);
    canvas.drawLine(c, pBottom, paint);
  }

  @override
  bool shouldRepaint(covariant IsometricCubePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// CustomPainter untuk Ikon Storefront / Toko (Pembeli Bisnis)
class StorefrontPainter extends CustomPainter {
  const StorefrontPainter({
    required this.color,
    this.strokeWidth = 2.0,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Atap miring segitiga bersahabat
    final roofPeakY = h * 0.12;
    final roofBaseY = h * 0.45;
    final leftX = w * 0.14;
    final rightX = w * 0.86;
    final bottomY = h * 0.88;

    final buildingPath = Path()
      ..moveTo(cx, roofPeakY)
      ..lineTo(rightX, roofBaseY)
      ..lineTo(rightX, bottomY)
      ..lineTo(leftX, bottomY)
      ..lineTo(leftX, roofBaseY)
      ..close();

    canvas.drawPath(buildingPath, paint);

    // Pintu toko di tengah bawah
    final doorW = w * 0.28;
    final doorH = h * 0.32;
    final doorLeft = cx - doorW / 2;
    final doorRight = cx + doorW / 2;
    final doorTop = bottomY - doorH;

    final doorPath = Path()
      ..moveTo(doorLeft, bottomY)
      ..lineTo(doorLeft, doorTop + 4)
      ..quadraticBezierTo(doorLeft, doorTop, cx, doorTop)
      ..quadraticBezierTo(doorRight, doorTop, doorRight, doorTop + 4)
      ..lineTo(doorRight, bottomY);

    canvas.drawPath(doorPath, paint);
  }

  @override
  bool shouldRepaint(covariant StorefrontPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// CustomPainter untuk garis konektor alur (Dashed ──●──▶)
class SmartMatchConnectorPainter extends CustomPainter {
  const SmartMatchConnectorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..color = const Color(0xFF7DD3FC)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final primaryPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;

    final cy = size.height / 2;
    final w = size.width;

    // 1. Garis putus-putus kiri
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 2.0;
    while (startX < 24.0) {
      canvas.drawLine(
        Offset(startX, cy),
        Offset(math.min(startX + dashWidth, 24.0), cy),
        lightPaint,
      );
      startX += dashWidth + dashSpace;
    }

    // 2. Garis solid tengah dan titik lingkaran
    canvas.drawLine(Offset(24, cy), Offset(50, cy), primaryPaint);
    canvas.drawCircle(Offset(37, cy), 3.8, fillPaint);

    // 3. Garis putus-putus kanan
    startX = 50.0;
    while (startX < 66.0) {
      canvas.drawLine(
        Offset(startX, cy),
        Offset(math.min(startX + dashWidth, 66.0), cy),
        lightPaint,
      );
      startX += dashWidth + dashSpace;
    }

    // 4. Panah segitiga kanan
    final arrowPath = Path()
      ..moveTo(w - 2, cy)
      ..lineTo(w - 8, cy - 4.0)
      ..lineTo(w - 8, cy + 4.0)
      ..close();

    canvas.drawPath(arrowPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant SmartMatchConnectorPainter oldDelegate) => false;
}
