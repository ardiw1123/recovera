import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/listing_repository.dart';
import '../home/screens/home_screen.dart';
import '../seller/screens/seller_dashboard_screen.dart';
import '../seller/repositories/seller_repository.dart';
import '../seller/screens/upload_stock_flow_screen.dart';
import '../auth/screens/profile_screen.dart';
import '../seller/screens/seller_inventory_screen.dart';
import '../sky_balance/sky_balance_screen.dart';
import '../transactions/screens/buyer_transaction_screen.dart';

/// PBI-05 & Seller Journey — Bottom Navigation Bar
///
/// Beradaptasi sesuai role pengguna:
/// • Seller (Penjual): Tab Stok menampilkan `SellerInventoryScreen` ("Stok Saya" sesuai referensi tetap)
///   dan tombol "+ Tambah" langsung membuka `UploadStockFlowScreen`.
/// • Buyer (Pembeli): Tab Stok dihilangkan sepenuhnya dari antarmuka pembeli (hanya Home, Profil, Saran).
class MainShell extends StatefulWidget {
  final ListingRepository? listingRepository;
  final SellerRepository? sellerRepository;
  final Widget? stokPage;
  final Widget? profilePage;
  final Widget? feedbackPage;

  const MainShell({
    super.key,
    this.listingRepository,
    this.sellerRepository,
    this.stokPage,
    this.profilePage,
    this.feedbackPage,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = index;
      });
    }
  }

  void _handleGameExit() {
    setState(() {
      // Kembali ke tab sebelumnya jika bukan game (index 2), jika tidak kembali ke Beranda (0)
      _currentIndex = (_previousIndex != 2) ? _previousIndex : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthRepository.instance,
      builder: (context, _) {
        final isSeller = AuthRepository.instance.isSeller;
        final profile = AuthRepository.instance.currentUserProfile;
        final buyerLat = profile?.baseLat ?? -6.2088;
        final buyerLng = profile?.baseLng ?? 106.8456;

        // Daftar halaman adaptif berdasarkan role
        // • Seller: Beranda (0), Stok (1), Game (2), Profil (3)
        // • Buyer: Beranda (0), Riwayat (1), Game (2), Profil (3)
        final activeIndex = _currentIndex.clamp(0, 3);
        final isGameActive = activeIndex == 2;

        final pages = isSeller
            ? <Widget>[
                SellerDashboardScreen(repository: widget.sellerRepository),
                widget.stokPage ??
                    SellerInventoryScreen(repository: widget.sellerRepository),
                SkyBalanceScreen(
                  isActive: isGameActive,
                  onExit: _handleGameExit,
                ),
                widget.profilePage ?? const ProfileScreen(),
              ]
            : <Widget>[
                HomeScreen(
                  userLat: buyerLat,
                  userLng: buyerLng,
                  repository: widget.listingRepository,
                ),
                const BuyerTransactionScreen(),
                SkyBalanceScreen(
                  isActive: isGameActive,
                  onExit: _handleGameExit,
                ),
                widget.profilePage ?? const ProfileScreen(),
              ];

        return PopScope(
          canPop: activeIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (activeIndex != 0) {
              _onTabSelected(0);
            }
          },
          child: Scaffold(
            body: IndexedStack(index: activeIndex, children: pages),
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
                      ? _buildSellerNavRow(activeIndex)
                      : _buildBuyerNavRow(activeIndex),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Bottom Nav Row untuk Penjual (Sesuai seller-inventory-screen.png) ─────
  Widget _buildSellerNavRow(int activeIndex) {
    return Row(
      children: [
        Expanded(
          child: _NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Beranda',
            isActive: activeIndex == 0,
            onTap: () => _onTabSelected(0),
          ),
        ),
        Expanded(
          child: _NavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: 'Stok',
            isActive: activeIndex == 1,
            onTap: () => _onTabSelected(1),
          ),
        ),
        // Tombol Tambah di tengah
        Expanded(
          child: GestureDetector(
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Tambah',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _NavItem(
            icon: Icons.sports_esports_outlined,
            activeIcon: Icons.sports_esports,
            label: 'Game',
            isActive: activeIndex == 2,
            onTap: () => _onTabSelected(2),
          ),
        ),
        Expanded(
          child: _NavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profil',
            isActive: activeIndex == 3,
            onTap: () => _onTabSelected(3),
          ),
        ),
      ],
    );
  }

  // ── Bottom Nav Row untuk Pembeli (Role guard: Tab Stok dihilangkan sepenuhnya) ──
  Widget _buildBuyerNavRow(int activeIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _NavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Beranda',
          isActive: activeIndex == 0,
          onTap: () => _onTabSelected(0),
        ),
        _NavItem(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long,
          label: 'Riwayat',
          isActive: activeIndex == 1,
          onTap: () => _onTabSelected(1),
        ),
        _NavItem(
          icon: Icons.sports_esports_outlined,
          activeIcon: Icons.sports_esports,
          label: 'Game',
          isActive: activeIndex == 2,
          onTap: () => _onTabSelected(2),
        ),
        _NavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profil',
          isActive: activeIndex == 3,
          onTap: () => _onTabSelected(3),
        ),
      ],
    );
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
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.slateText;
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.primary : AppColors.slateText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
