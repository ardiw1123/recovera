import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/listing_repository.dart';
import '../home/screens/home_screen.dart';
import '../stok/screens/stok_screen.dart';
import '../seller/screens/seller_inventory_screen.dart';
import '../seller/screens/upload_stock_flow_screen.dart';
import '../auth/screens/profile_screen.dart';
import '../auth/screens/login_screen.dart';
import '../feedback/screens/saran_kesan_screen.dart';

/// PBI-05 & Seller Journey — Bottom Navigation Bar
///
/// Beradaptasi sesuai role pengguna:
/// • Seller (Penjual): Tab Stok menampilkan `SellerInventoryScreen` ("Stok Saya" sesuai referensi tetap)
///   dan tombol "+ Tambah" langsung membuka `UploadStockFlowScreen`.
/// • Buyer (Pembeli): Tab Stok menampilkan `StokScreen` (Katalog lelang pembeli), tanpa akses rute penjual.
class MainShell extends StatefulWidget {
  final ListingRepository? listingRepository;
  final Widget? stokPage;
  final Widget? profilePage;
  final Widget? feedbackPage;

  const MainShell({
    super.key,
    this.listingRepository,
    this.stokPage,
    this.profilePage,
    this.feedbackPage,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthRepository.instance,
      builder: (context, _) {
        final isSeller = AuthRepository.instance.isSeller;
        final profile = AuthRepository.instance.currentUserProfile;
        final buyerLat = profile?.baseLat ?? -6.2088;
        final buyerLng = profile?.baseLng ?? 106.8456;

        // Daftar halaman adaptif berdasarkan role:
        // Buyer: Home (katalog lelang & stok terintegrasi), Profil, Saran
        // Seller: Beranda, Stok Saya, Profil, Saran
        final pages = isSeller
            ? <Widget>[
                const SellerInventoryScreen(),
                widget.stokPage ?? const SellerInventoryScreen(),
                widget.profilePage ?? const ProfileScreen(),
                widget.feedbackPage ?? const SaranKesanScreen(),
              ]
            : <Widget>[
                HomeScreen(
                  userLat: buyerLat,
                  userLng: buyerLng,
                  repository: widget.listingRepository,
                ),
                widget.profilePage ?? const ProfileScreen(),
                widget.feedbackPage ?? const SaranKesanScreen(),
              ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex.clamp(0, pages.length - 1),
            children: pages,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: isSeller
                    ? _buildSellerNavRow()
                    : _buildBuyerNavRow(),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Bottom Nav Row untuk Penjual (Sesuai seller-inventory-screen.png) ─────
  Widget _buildSellerNavRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _NavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Beranda',
          isActive: _currentIndex == 0,
          onTap: () => setState(() => _currentIndex = 0),
        ),
        _NavItem(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2_rounded,
          label: 'Stok',
          isActive: _currentIndex == 1,
          onTap: () => setState(() => _currentIndex = 1),
        ),
        // Tombol Tambah di tengah
        GestureDetector(
          key: const Key('nav_seller_add_stock'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UploadStockFlowScreen(),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 24,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 2),
                Text(
                  'Tambah',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        _NavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profil',
          isActive: _currentIndex == 2,
          onTap: () => setState(() => _currentIndex = 2),
        ),
        _NavItem(
          icon: Icons.chat_bubble_outline_rounded,
          activeIcon: Icons.chat_bubble_rounded,
          label: 'Saran',
          isActive: _currentIndex == 3,
          onTap: () => setState(() => _currentIndex = 3),
        ),
        _NavItem(
          icon: Icons.logout_rounded,
          activeIcon: Icons.logout_rounded,
          label: 'Keluar',
          isActive: false,
          iconColor: AppColors.error,
          onTap: () => _showLogoutDialog(context),
        ),
      ],
    );
  }

  // ── Bottom Nav Row untuk Pembeli (Home, Profil, Saran, Keluar) ───────────
  Widget _buildBuyerNavRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _NavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
          isActive: _currentIndex == 0,
          onTap: () => setState(() => _currentIndex = 0),
        ),
        _NavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profil',
          isActive: _currentIndex == 1,
          onTap: () => setState(() => _currentIndex = 1),
        ),
        _NavItem(
          icon: Icons.chat_bubble_outline_rounded,
          activeIcon: Icons.chat_bubble_rounded,
          label: 'Saran',
          isActive: _currentIndex == 2,
          onTap: () => setState(() => _currentIndex = 2),
        ),
        _NavItem(
          icon: Icons.logout_rounded,
          activeIcon: Icons.logout_rounded,
          label: 'Keluar',
          isActive: false,
          iconColor: AppColors.error,
          onTap: () => _showLogoutDialog(context),
        ),
      ],
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(
              'Konfirmasi Keluar',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun Recovera?',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Keluar',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthRepository.instance.logout();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavItem — Item tunggal di bottom nav bar
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? (isActive ? AppColors.primary : AppColors.slateText);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? (activeIcon ?? icon) : icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
