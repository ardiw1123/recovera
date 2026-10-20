import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../widgets/auth_widgets.dart';
import 'location_management_screen.dart';
import 'login_screen.dart';

/// PBI-03 — Layar Profil & Keamanan Akun Recovera
///
/// Design: Header biru "Profil Saya" + overlapping white card
///         dengan avatar melayang, nama perusahaan, badge Terverifikasi,
///         menu list dengan ikon, dan tombol Logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _defaultCompany = 'PT Maju Sejahtera';
  static const _defaultRole = 'UMKM Kuliner';
  static const _defaultCity = 'Depok';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      await AuthRepository.instance.fetchProfile();
      if (mounted) setState(() {});
    } catch (_) {
      // Fallback ke kredensial/token tersimpan jika offline
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthRepository.instance,
      builder: (context, _) {
        final profile = AuthRepository.instance.currentUserProfile;
        final tokens = AuthRepository.instance.currentTokens;

        final company = profile?.companyName ??
            profile?.name ??
            tokens?.name ??
            _defaultCompany;
        final role = profile?.role != null
            ? (profile!.role == 'seller'
                ? 'Distributor (Seller)'
                : 'UMKM Kuliner (Buyer)')
            : (tokens?.role == 'seller'
                ? 'Distributor (Seller)'
                : _defaultRole);
        final city = profile?.city ?? _defaultCity;

        return Scaffold(
          backgroundColor: AppColors.canvasBg,
          body: Stack(
            children: [
              Column(
                children: [
              // ── Header Biru ────────────────────────────────────────
              _ProfileHeader(context: context),

              // ── Scrollable Content ─────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Transform.translate(
                    offset: const Offset(0, -44), // avatar overlap
                    child: Column(
                      children: [
                        // White Card mulai dari sini
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(32)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                blurRadius: 30,
                                offset: const Offset(0, -12),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 24,
                              right: 24,
                              top: 60, // ruang untuk avatar yang melayang
                              bottom: 32,
                            ),
                            child: Column(
                              children: [
                                // ── Identitas Perusahaan ───────────────
                                Text(
                                  company,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkNavy,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$role • $city',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.slateText,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // ── Badge Terverifikasi ────────────────
                                _VerifiedBadge(),
                                const SizedBox(height: 28),

                                // ── Menu List ─────────────────────────
                                _ProfileMenuList(),
                                const SizedBox(height: 24),

                                // ── Divider ────────────────────────────
                                const Divider(
                                    color: Color(0xFFF1F5F9), thickness: 1.5),
                                const SizedBox(height: 16),

                                // ── Logout Button ──────────────────────
                                PillButton(
                                  label: 'Logout',
                                  outlined: true,
                                  backgroundColor: AppColors.error,
                                  foregroundColor: AppColors.error,
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 16,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () => _showLogoutDialog(context),
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
            ],
          ),

          // ── Avatar Melayang (Overlapping) ──────────────────────────────
          _FloatingAvatar(context: context),
        ],
      ),
    );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Konfirmasi Logout',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.darkNavy,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun Recovera?',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.slateText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.slateText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthRepository.instance.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50)),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets lokal
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.24,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tombol kembali
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.white,
                    size: 16,
                  ),
                ),
              ),
              // Judul header
              Text(
                'Profil Saya',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                  letterSpacing: 0.3,
                ),
              ),
              // Dot status online (kanan)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF34D399),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingAvatar extends StatelessWidget {
  const _FloatingAvatar({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    final headerHeight = MediaQuery.of(context).size.height * 0.24;
    return Positioned(
      top: headerHeight - 44, // melayang melewati batas header
      left: 0,
      right: 0,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Avatar utama
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.secondary],
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'lib/assets/recovera-logo-mark.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => Center(
                    child: Text(
                      'MS',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Badge kamera edit (pojok kanan bawah)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFFE2E8F0), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.successBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF059669)),
          const SizedBox(width: 5),
          Text(
            'Terverifikasi',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu List Profil
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileMenuList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final profile = AuthRepository.instance.currentUserProfile;
    final address = profile?.address?.trim();
    final city = profile?.city?.trim();
    final locationSubtitle = (address != null && address.isNotEmpty)
        ? address
        : (city != null && city.isNotEmpty
            ? '$city, Indonesia'
            : 'Atur Lokasi Pengiriman');

    final items = [
      _ProfileMenuItem(
        key: const Key('menu_business_info'),
        icon: Icons.business_rounded,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: AppColors.primary,
        label: 'Informasi Bisnis',
        onTap: () {},
      ),
      _ProfileMenuItem(
        key: const Key('menu_location_and_delivery'),
        icon: Icons.location_on_outlined,
        iconBg: const Color(0xFFE0F7FA),
        iconColor: AppColors.secondary,
        label: 'Lokasi & Pengiriman',
        subtitle: locationSubtitle,
        subtitleColor: AppColors.secondary,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const LocationManagementScreen(),
            ),
          );
        },
      ),
      _ProfileMenuItem(
        key: const Key('menu_security_biometrics'),
        icon: Icons.lock_outline_rounded,
        iconBg: AppColors.successBg,
        iconColor: const Color(0xFF059669),
        label: 'Pengaturan Keamanan & Biometrik',
        subtitle: 'Sidik Jari Aktif',
        subtitleColor: const Color(0xFF059669),
        onTap: () {},
      ),
      _ProfileMenuItem(
        key: const Key('menu_feedback'),
        icon: Icons.chat_bubble_outline_rounded,
        iconBg: const Color(0xFFEEF2FF),
        iconColor: const Color(0xFF6366F1),
        label: 'Saran & Kesan',
        onTap: () {
          // TODO: navigasi ke PBI-08 Saran & Kesan screen
        },
      ),
    ];

    return Column(
      children: items,
    );
  }
}

class _ProfileMenuItem extends StatefulWidget {
  const _ProfileMenuItem({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  final Color? subtitleColor;

  @override
  State<_ProfileMenuItem> createState() => _ProfileMenuItemState();
}

class _ProfileMenuItemState extends State<_ProfileMenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _pressed
              ? const Color(0xFFF8FAFC)
              : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed
                ? const Color(0xFFE2E8F0)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: widget.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 18, color: widget.iconColor),
            ),
            const SizedBox(width: 14),

            // Label + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: widget.subtitleColor ?? AppColors.slateText,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Arrow
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
