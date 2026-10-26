import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/seller_dashboard_model.dart';
import '../repositories/seller_repository.dart';
import 'esg_certificate_list_screen.dart';
import 'upload_stock_flow_screen.dart';
import '../../transactions/screens/seller_order_screen.dart';
import '../../chat/screens/chatbot_screen.dart';

/// Halaman Beranda Seller — Dashboard Ringkasan
/// menggantikan SellerInventoryScreen di tab Beranda.
/// Menampilkan ringkasan aktif, stok expired, dan aktivitas terbaru.
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({
    super.key,
    this.repository,
  });

  final SellerRepository? repository;

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final SellerRepository _repository;
  Timer? _refreshTimer;
  bool _isLoading = false;
  String? _errorMessage;
  SellerDashboardData? _dashboardData;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SellerRepository.instance;
    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repository.loadDashboard();
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Helper untuk format waktu relatif
  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays >= 1) {
        // Jika lebih dari 1 hari, gunakan format "Kemarin/Hari ini/Bulan lalu"
        if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
          return 'Hari ini, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }
        if (dt.day == now.subtract(const Duration(days: 1)).day &&
            dt.month == now.subtract(const Duration(days: 1)).month &&
            dt.year == now.subtract(const Duration(days: 1)).year) {
          return 'Kemarin, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }
        return '${dt.day}/${dt.month}/${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        // Kurang dari 1 hari
        if (diff.inMinutes > 0) {
          return '${diff.inMinutes} menit lalu';
        } else if (diff.inSeconds > 0) {
          return '${diff.inSeconds} detik lalu';
        } else {
          return 'Baru saja';
        }
      }
    } catch (_) {
      return timestamp;
    }
  }

  // Warna latar badge berdasarkan sisa hari
  Color _getBadgeColor(int daysRemaining) {
    if (daysRemaining < 7) {
      return AppColors.error; // merah
    } else if (daysRemaining <= 14) {
      return Color(0xFFFF8C00); // oranye
    } else {
      return AppColors.success; // hijau
    }
  }

  String _getBadgeLabel(int daysRemaining) {
    if (daysRemaining < 1) {
      return 'Kedaluwarsa';
    } else if (daysRemaining == 1) {
      return '1 hari tersisa';
    } else {
      return '$daysRemaining hari tersisa';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: _buildBody(),
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }



  Widget _buildBody() {
    // Jika belum ada data, tampilkan loading
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // Jika ada error, tampilkan pesan error + tombol retry
    if (_errorMessage != null && _dashboardData == null) {
      return _buildErrorState();
    }

    // Jika tidak ada data, tampilkan empty state
    if (_dashboardData == null) {
      return const Center(child: Text('Tidak ada data'));
    }

    final data = _dashboardData!;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 5a. Header Section
          _buildHeader(data.companyName),

          const SizedBox(height: 24),

          // 5b. Bento Summary Cards
          _buildBentoCards(data),

          const SizedBox(height: 24),

          // 5c. Card Stok Mendekati Expired
          _buildNearExpiryCard(data.nearExpiryListings),

          const SizedBox(height: 24),

          // 5d. Card Aktivitas Terbaru
          _buildRecentActivitiesCard(data.recentActivities),

          const SizedBox(height: 24),

          // 5e. Card Sertifikat ESG
          _buildEsgCertificateCard(data),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(String companyName) {
    return Row(
      children: [
        // Logo Recovera horizontal
        Container(
          width: 120,
          height: 40,
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/images/recovera_logo_horizontal.png'),
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Teks sapaan dan subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, $companyName',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bersama kita memulihkan nilai pangan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slateText,
                ),
              ),
            ],
          ),
        ),
        // Ikon Riwayat Pesanan Seller di kanan logo
        GestureDetector(
          key: const Key('btn_seller_orders'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SellerOrderScreen(),
              ),
            );
          },
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: Color(0xFF03045E),
            ),
          ),
        ),
        // Ikon notifikasi di kanan logo
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            size: 20,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildBentoCards(SellerDashboardData data) {
    final activeCount = data.activeListingsCount;
    final currentMonthOrders = data.currentMonthOrdersCount;
    final prevMonthActive = data.prevMonthActiveCount;
    final prevMonthOrders = data.prevMonthOrdersCount;

    // Calculate percentage change
    String calculatePercent(int current, int previous) {
      if (previous == 0) {
        return 'Baru'; // atau "—"
      }
      final percent = ((current - previous) / previous * 100).round();
      if (percent > 0) {
        return '+$percent%';
      } else if (percent < 0) {
        return '$percent%';
      } else {
        return '—';
      }
    }

    return Row(
      children: [
        // Card kiri: Stok Aktif
        Expanded(
          child: _BentoCard(
            label: 'Stok Aktif',
            value: activeCount.toString(),
            subtitle: calculatePercent(activeCount, prevMonthActive),
            icon: Icons.inventory,
            color: AppColors.primary,
            bgColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        // Card kanan: Transaksi Bulan Ini
        Expanded(
          child: _BentoCard(
            label: 'Transaksi Bulan Ini',
            value: currentMonthOrders.toString(),
            subtitle: calculatePercent(currentMonthOrders, prevMonthOrders),
            icon: Icons.receipt_long,
            color: const Color(0xFF10B981), // success green
            bgColor: Colors.white,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SellerOrderScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNearExpiryCard(List<NearExpiryItem>? listings) {
    final nearExpiry = listings ?? [];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              Text(
                'Stok Mendekati Expired',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (nearExpiry.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Tidak ada stok yang mendekati expired 👍',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.slateText,
                ),
              ),
            )
          else
            ...List.generate(
              nearExpiry.length,
              (index) {
                final item = nearExpiry[index];
                return _NearExpiryItemCard(
                  item: item,
                  badgeColor: _getBadgeColor(item.daysRemaining),
                  badgeLabel: _getBadgeLabel(item.daysRemaining),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitiesCard(List<RecentActivity>? activities) {
    final actList = activities ?? [];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                'Aktivitas Terbaru',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (actList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Tidak ada aktivitas terbaru',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.slateText,
                ),
              ),
            )
          else
            ...List.generate(
              min(actList.length, 5),
              (index) => _RecentActivityItem(
                activity: actList[index],
                formatTimestamp: _formatTimestamp,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEsgCertificateCard(SellerDashboardData data) {
    final count = data.esgCertificateCount;
    final carbon = data.totalCarbonSaved;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EsgCertificateListScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.eco,
                    color: Colors.green.shade700,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Sertifikat ESG',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'BOT Chain',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count > 0
                            ? '$count sertifikat diterbitkan (${carbon.toStringAsFixed(1)} kg CO2e)'
                            : 'Pencatatan donasi pangan surplus & jejak karbon',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.slateText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Gagal Memuat Dashboard',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.slateText,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.38),
            blurRadius: 14,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        key: const Key('fab_chatbot_seller'),
        tooltip: 'Rera',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ChatbotScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.smart_toy_rounded, color: AppColors.white, size: 26),
      ),
    );
  }
}

// ─── Widget Card Bento ──────────────────────────────────────────────
class _BentoCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _BentoCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slateText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.slateText,
            ),
          ),
        ],
      ),
    ),
  );
}
}

// ─── Widget Item Stok Mendekati Expired ─────────────────────────────
class _NearExpiryItemCard extends StatelessWidget {
  final NearExpiryItem item;
  final Color badgeColor;
  final String badgeLabel;

  const _NearExpiryItemCard({
    required this.item,
    required this.badgeColor,
    required this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Thumbnail produk sederhana
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Icon(
              Icons.local_drink_rounded,
              size: 24,
              color: badgeColor,
            ),
          ),
          const SizedBox(width: 12),
          // Detail produk
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.qty} ${item.unit}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.slateText,
                  ),
                ),
              ],
            ),
          ),
          // Badge sisa hari
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeLabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widget Item Aktivitas Terbaru ───────────────────────────────────
class _RecentActivityItem extends StatelessWidget {
  final RecentActivity activity;
  final Function(String?) formatTimestamp;

  const _RecentActivityItem({
    required this.activity,
    required this.formatTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _getIconForType(activity.type);
    final iconColor = _getIconColorForType(activity.type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, size: 18, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  activity.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.slateText,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Text(
            formatTimestamp(activity.timestamp),
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.slateText,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'sold':
        return Icons.remove_circle_rounded;
      case 'uploaded':
        return Icons.upload_rounded;
      case 'expired':
        return Icons.remove_circle_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color _getIconColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'sold':
        return AppColors.error;
      case 'uploaded':
        return AppColors.primary;
      case 'expired':
        return AppColors.error;
      default:
        return AppColors.slateText;
    }
  }
}