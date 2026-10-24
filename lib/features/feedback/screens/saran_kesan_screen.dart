import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/recovera_wave_header.dart';

class SaranKesanScreen extends StatelessWidget {
  const SaranKesanScreen({super.key});

  static const _kesan =
      'Perkuliahan Mobile memberikan pengalaman yang menyenangkan dalam memahami proses pengembangan aplikasi mobile. Materi yang diberikan membantu saya memahami bagaimana sebuah ide dapat dikembangkan menjadi aplikasi yang memiliki tampilan menarik dan fungsional.';
  static const _saran =
      'Semoga pembelajaran dapat terus dikembangkan dengan lebih banyak contoh project dan studi kasus yang dekat dengan kebutuhan pengembangan aplikasi mobile saat ini, sehingga mahasiswa dapat semakin memahami penerapan materi secara langsung.';
  static const _terimaKasih =
      'Terima kasih atas ilmu, arahan, dan pengalaman yang diberikan selama perkuliahan.';

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.primary,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.canvasBg,
        body: Column(
          children: [
            RecoveraWaveHeader(
              height: statusBarHeight + 68,
              child: Column(
                children: [
                  SizedBox(height: statusBarHeight),
                  SizedBox(
                    height: 68,
                    child: Center(
                      child: Text(
                        'Saran & Kesan',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LecturerCard(),
                    const SizedBox(height: 16),
                    const _ReflectionCard(
                      title: 'Kesan Perkuliahan',
                      text: _kesan,
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: AppColors.primary,
                      iconBackground: Color(0xFFE8F4FC),
                    ),
                    const SizedBox(height: 12),
                    const _ReflectionCard(
                      title: 'Saran untuk Perkuliahan',
                      text: _saran,
                      icon: Icons.lightbulb_outline_rounded,
                      iconColor: Color(0xFF9A6500),
                      iconBackground: Color(0xFFFFF4D8),
                    ),
                    const SizedBox(height: 12),
                    const _ThankYouCard(text: _terimaKasih),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LecturerCard extends StatelessWidget {
  const _LecturerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7EEF6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B4E75).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const _LecturerAvatar(),
          const SizedBox(height: 10),
          Text(
            'BAGUS MUHAMMAD AKBAR',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.darkNavy,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5FC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.school_rounded,
                  color: AppColors.primary,
                  size: 19,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Pemrograman Mobile',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 16,
                color: AppColors.slateText,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Saran & Kesan Perkuliahan',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slateText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LecturerAvatar extends StatelessWidget {
  const _LecturerAvatar();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Foto dosen pengampu Pemrograman Mobile',
      child: SizedBox(
        width: 132,
        height: 128,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 18,
              child: Container(
                width: 108,
                height: 108,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white,
                  border: Border.all(color: const Color(0xFFD6A43B), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8C6419).withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'lib/assets/lecturer-mobile.png',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.1),
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 0,
              child: CustomPaint(size: Size(34, 27), painter: _CrownPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final crown = Path()
      ..moveTo(size.width * 0.08, size.height * 0.27)
      ..lineTo(size.width * 0.32, size.height * 0.48)
      ..lineTo(size.width * 0.42, size.height * 0.08)
      ..lineTo(size.width * 0.59, size.height * 0.46)
      ..lineTo(size.width * 0.89, size.height * 0.19)
      ..lineTo(size.width * 0.80, size.height * 0.78)
      ..lineTo(size.width * 0.17, size.height * 0.78)
      ..close();
    final fill = Paint()
      ..color = const Color(0xFFD6A43B)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = const Color(0xFF9A6500)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(crown, fill);
    canvas.drawPath(crown, outline);
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.9),
      Offset(size.width * 0.8, size.height * 0.9),
      outline,
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => false;
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({
    required this.title,
    required this.text,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final String title;
  final String text;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3EDF7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B4E75).withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 21, color: iconColor),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.55,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThankYouCard extends StatelessWidget {
  const _ThankYouCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD5EAF8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE6C66F)),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Color(0xFF9A6500),
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terima Kasih!',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkNavy,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
