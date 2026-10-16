import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_widgets.dart';
import '../../shell/main_shell.dart';
import 'register_screen.dart';

/// PBI-03 — Layar Login B2B Recovera
///
/// Design: Header biru 30% + overlapping white card
/// Fitur  : Email + password form, Google & Facebook social login,
///          "Lupa password?" link, navigasi ke Register.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: '');
  final _passCtrl = TextEditingController(text: '');

  bool _obscurePass = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // TODO: integrasi Ardi — POST /auth/login via Dio
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
    if (!mounted) return;
    // Navigasi ke MainShell (replace agar tidak bisa back ke login)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasBg,
      body: Column(
        children: [
          // ── Header Biru ─────────────────────────────────────────────
          AuthHeader(
            leftAction: HeaderIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.maybePop(context),
              semanticLabel: 'Kembali',
            ),
            rightAction: HeaderIconButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.maybePop(context),
              semanticLabel: 'Tutup',
            ),
            child: _buildHeaderGraphic(),
          ),

          // ── Wave Card Putih ────────────────────────────────────────────
          // Container biru sebagai backdrop supaya wave clip terlihat
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryLight,
                    AppColors.primaryLight,
                  ],
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ClipPath(
                  clipper: _WaveCardClipper(),
                  child: Container(
                    width: double.infinity,
                    color: AppColors.white,
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 64, // ruang ekstra untuk area kurva wave
                      bottom: 44,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Judul ────────────────────────────────────
                          Text(
                            'Welcome back!',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkNavy,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Halo, silakan login untuk melanjutkan.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.slateText,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Social Login Row ────────────────────────
                          Row(
                            children: [
                              SocialLoginButton(
                                label: 'Google',
                                onTap: () {},
                                logoWidget: _GoogleLogo(),
                              ),
                              const SizedBox(width: 12),
                              SocialLoginButton(
                                label: 'Facebook',
                                onTap: () {},
                                filled: true,
                                logoWidget: const Icon(
                                  Icons.facebook_rounded,
                                  color: AppColors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Divider ─────────────────────────────────
                          _OrDivider(),
                          const SizedBox(height: 20),

                          // ── Email ───────────────────────────────────
                          PillTextField(
                            label: 'Email Address',
                            hint: 'nama@perusahaan.com',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            suffixIcon:
                                _emailCtrl.text.isNotEmpty &&
                                        _emailCtrl.text.contains('@')
                                    ? const _ValidCheckIcon()
                                    : null,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Email wajib diisi';
                              }
                              if (!v.contains('@')) {
                                return 'Format email tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── Password ─────────────────────────────────
                          PillTextField(
                            label: 'Password',
                            hint: '••••••••',
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePass = !_obscurePass,
                              ),
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                                color: AppColors.slateText,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password wajib diisi';
                              }
                              if (v.length < 8) {
                                return 'Password minimal 8 karakter';
                              }
                              return null;
                            },
                          ),

                          // ── Lupa Password ───────────────────────────
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              child: Text(
                                'Lupa password?',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.slateText,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ── Tombol Login ─────────────────────────────
                          PillButton(
                            label: 'Login Akun',
                            onPressed: _handleLogin,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 24),

                          // ── Sign up Redirect ─────────────────────────
                          Center(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.slateText,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Belum punya akun? ',
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen(),
                                        ),
                                      ),
                                      child: Text(
                                        'Sign up',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logo / Emblem di tengah header ──────────────────────────────────────
  Widget _buildHeaderGraphic() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.4),
            blurRadius: 48,
            spreadRadius: 12,
          ),
        ],
      ),
      child: Image.asset(
        'lib/assets/recovera-logo-mark.png',
        width: 80,
        height: 80,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => const Icon(
          Icons.recycling_rounded,
          color: AppColors.white,
          size: 50,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WaveCardClipper — Hanya melengkungkan TEPI ATAS card
//
// Area di belakang clip berwarna BIRU (dari Container parent),
// sehingga lengkungan terlihat sebagai transisi organik header→card.
//
//  Sisi kiri (y=48)                                Sisi kanan (y=24)
//      ╲                                              ╱
//       ╲ cubicTo ── puncak (y≈0) ── cubicTo ── dip ╱
//        ╲───────────────────────────────────────────╱
// ─────────────────────────────────────────────────────────────────────────────

class _WaveCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Mulai dari kiri bawah
    path.moveTo(0, h);

    // Naik ke titik awal wave di sisi kiri (y=48, lebih rendah)
    path.lineTo(0, 48);

    // ── Wave Bézier pertama: kiri → tengah ─────────────────────────────
    // Naik tajam lalu melengkung organik ke tengah
    path.cubicTo(
      0, 12,          // cp1: naik tajam dari y=48
      w * 0.30, 0,    // cp2: puncak di ~30% lebar
      w * 0.50, 22,   // end: sedikit turun di tengah
    );

    // ── Wave Bézier kedua: tengah → kanan ──────────────────────────────
    // Dip lembut lalu naik menuju tepi kanan
    path.cubicTo(
      w * 0.70, 44,   // cp1: dip ke bawah di ~70%
      w * 0.90, 4,    // cp2: naik tajam menuju kanan
      w, 24,          // end: tepi kanan (lebih tinggi dari kiri)
    );

    // Sisi kanan turun ke bawah
    path.lineTo(w, h);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets lokal (private)
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4285F4),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'atau login dengan email',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.slateText,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
      ],
    );
  }
}

class _ValidCheckIcon extends StatelessWidget {
  const _ValidCheckIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.successBg,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 14,
        color: AppColors.success,
      ),
    );
  }
}
