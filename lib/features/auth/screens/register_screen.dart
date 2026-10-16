import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

/// PBI-03 — Layar Registrasi B2B Recovera
///
/// Design: Header biru + badge "Pendaftaran Mitra Resmi" + overlapping white card
/// Field  : Nama Perusahaan, Email, Password, Role (Seller / Buyer)
/// Extra  : Checkbox Syarat & Ketentuan
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String _selectedRole = 'buyer';
  bool _obscurePass = true;
  bool _agreeTerms = false;
  bool _isLoading = false;

  static const _roleOptions = [
    {'value': 'seller', 'label': 'Distributor (Seller) — Likuidasi Stok'},
    {'value': 'buyer', 'label': 'UMKM (Buyer) — Bahan Baku Terjangkau'},
  ];

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Harap setujui Syarat & Ketentuan terlebih dahulu.',
              style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthRepository.instance.register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        role: _selectedRole,
        name: _namaCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Akun berhasil dibuat! Silakan login.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.white)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasBg,
      body: Column(
        children: [
          // ── Header Biru ──────────────────────────────────────────────
          AuthHeader(
            height: MediaQuery.of(context).size.height * 0.28,
            leftAction: HeaderIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.maybePop(context),
              semanticLabel: 'Kembali ke Login',
            ),
            rightAction: HeaderIconButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.maybePop(context),
              semanticLabel: 'Tutup',
            ),
            child: _OfficialBadge(),
          ),

          // ── Wave Card Putih ────────────────────────────────────────
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
                      top: 64,
                      bottom: 44,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Judul ──────────────────────────────────────
                          Text(
                            'Halo!',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkNavy,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Buat akun Recovera untuk melanjutkan.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.slateText,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Nama Perusahaan ────────────────────────────
                          PillTextField(
                            label: 'Nama Perusahaan',
                            hint: 'Contoh: PT Pangan Nusantara',
                            controller: _namaCtrl,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                          ),
                          const SizedBox(height: 14),

                          // ── Email ──────────────────────────────────────
                          PillTextField(
                            label: 'Email Address',
                            hint: 'kontak@perusahaan.com',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Wajib diisi';
                              if (!v.contains('@')) {
                                return 'Format email tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // ── Password ───────────────────────────────────
                          PillTextField(
                            label: 'Password',
                            hint: 'Minimal 8 karakter',
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            textInputAction: TextInputAction.done,
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                                color: AppColors.slateText,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Wajib diisi';
                              if (v.length < 8) return 'Minimal 8 karakter';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // ── Role Dropdown ──────────────────────────────
                          _RoleDropdown(
                            value: _selectedRole,
                            options: _roleOptions,
                            onChanged: (v) =>
                                setState(() => _selectedRole = v ?? 'buyer'),
                          ),
                          const SizedBox(height: 16),

                          // ── Terms Checkbox ─────────────────────────────
                          _TermsCheckbox(
                            value: _agreeTerms,
                            onChanged: (v) =>
                                setState(() => _agreeTerms = v!),
                          ),
                          const SizedBox(height: 20),

                          // ── Tombol Buat Akun ───────────────────────────
                          PillButton(
                            label: 'Buat Akun',
                            onPressed: _handleRegister,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 20),

                          // ── Sign in Redirect ───────────────────────────
                          Center(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.slateText,
                                ),
                                children: [
                                  const TextSpan(text: 'Sudah punya akun? '),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const LoginScreen(),
                                        ),
                                      ),
                                      child: Text(
                                        'Sign in',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// _WaveCardClipper — Kurva Bézier asimetris (sama dengan login_screen)
// ─────────────────────────────────────────────────────────────────────────────

class _WaveCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    path.moveTo(0, h);
    path.lineTo(0, 48);

    // Wave Bézier pertama: kiri → tengah
    path.cubicTo(
      0, 12,
      w * 0.30, 0,
      w * 0.50, 22,
    );

    // Wave Bézier kedua: tengah → kanan
    path.cubicTo(
      w * 0.70, 44,
      w * 0.90, 4,
      w, 24,
    );

    path.lineTo(w, h);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets lokal
// ─────────────────────────────────────────────────────────────────────────────

class _OfficialBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Logo + Wordmark ─────────────────────────────────────────
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'lib/assets/recovera-logo-mark.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => const Icon(
                Icons.recycling_rounded,
                color: AppColors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Recovera',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ── Badge ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF34D399),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Pendaftaran Mitra Resmi Recovera',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<Map<String, String>> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 6),
          child: Text(
            'Role',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475569),
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.slateText),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.darkNavy,
          ),
          items: options
              .map((o) => DropdownMenuItem<String>(
                    value: o['value'],
                    child: Text(o['label']!),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.scale(
          scale: 0.9,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            shape: const CircleBorder(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF475569),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                      text: 'Dengan membuat akun, Anda menyetujui '),
                  TextSpan(
                    text: 'Syarat & Ketentuan',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const TextSpan(text: ' kami.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
