import '../../../data/repositories/app_prefs_repository.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/cached_order_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../data/services/order_api_service.dart';
import '../../../data/repositories/notification_repository.dart';
import '../models/seller_dashboard_model.dart';
import '../repositories/seller_repository.dart';
import 'upload_stock_flow_screen.dart';
import 'esg_certificate_list_screen.dart';
import 'seller_inventory_screen.dart';
import '../../transactions/screens/seller_order_screen.dart';
import '../../../features/home/screens/notification_list_screen.dart';
import '../../chat/screens/chatbot_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key, this.repository});

  final SellerRepository? repository;

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final SellerRepository _repository;
  late Timer? _refreshTimer;
  late final OrderRepository _ordersRepository;
  List<CachedOrderModel> _pendingOrders = [];
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  int _unreadNotificationCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  SellerDashboardData? _dashboardData;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SellerRepository.instance;
    _ordersRepository = OrderRepository(
      remoteClient: OrderApiService(client: ApiClient()),
    );
    _loadData();
    _loadUnreadNotificationCount();
    _startAutoRefresh();
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final notifications = await _notificationRepository.fetchNotifications();
      if (mounted) {
        setState(
          () => _unreadNotificationCount = notifications
              .where((item) => !item.isRead)
              .length,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
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
      final orders = await _ordersRepository.getOrders(forceRefresh: true);
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _pendingOrders = orders
              .where(
                (order) =>
                    order.status == 'paid' || order.status == 'in_progress',
              )
              .toList();
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
    final companyName = _dashboardData?.companyName ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _buildChatbotFab(),
      body: Column(
        children: [
          // ── Fixed Wave Header (Desain disamakan dengan Buyer Header) ──
          _buildFixedWaveHeader(companyName),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  /// Header Beranda Penjual dengan desain gelombang ombak (identik dengan Buyer)
  Widget _buildFixedWaveHeader(String companyName) {
    return Stack(
      children: [
        // Layer gelombang latar belakang (soft contrast)
        Positioned.fill(
          child: ClipPath(
            clipper: _HeaderWaveBackdropClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.5),
                    AppColors.secondary.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Layer gelombang utama dengan konten header tetap (fixed)
        ClipPath(
          clipper: _HeaderWaveClipper(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sisi Kiri: Logo Brand Recovera, Greeting Seller, dan Lokasi/Chips
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Logo Recovera & Teks Brand ──
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Image.asset(
                                  'lib/assets/recovera-logo-mark.png',
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.eco_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Recovera',
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'RECOVERA B2B',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF6EE7B7)
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 9,
                                        color: Color(0xFF6EE7B7),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Verified',
                                        style: GoogleFonts.inter(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF6EE7B7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),

                          // ── Greeting Seller: "Halo, [companyName]!" ──
                          Text(
                            'Halo, ${companyName.isNotEmpty ? companyName : "Mitra Bisnis"}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // ── Bar Lokasi Gudang & Chips Info ──
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: Color(0xFF90E0EF),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Gudang Utama',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.22,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.radar_rounded,
                                          size: 10,
                                          color: Color(0xFF90E0EF),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Radius < 15 km',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  ListenableBuilder(
                                    listenable: AppPrefsRepository.instance,
                                    builder: (context, _) {
                                      final cur = AppPrefsRepository
                                          .instance
                                          .selectedCurrency;
                                      final tz = AppPrefsRepository
                                          .instance
                                          .selectedTimezone;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.22,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '$cur • $tz',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ── Tombol Pesanan / Transaksi Masuk (Kanan Atas) ──
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SellerOrderScreen(),
                          ),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // ── Tombol Notifikasi (Kanan Atas) ──
                    GestureDetector(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationListScreen(),
                          ),
                        );
                        _loadUnreadNotificationCount();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          if (_unreadNotificationCount > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
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
      ],
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
          // 5a. Header telah dipindahkan ke top sticky wave header

          // 5b. Bento Summary Cards
          _buildBentoCards(data),

          const SizedBox(height: 24),

          _buildQuickActionsBar(),

          const SizedBox(height: 24),

          // 5c. Card Stok Mendekati Expired
          _buildNearExpiryCard(data.nearExpiryListings),

          const SizedBox(height: 24),

          // 5d. Card Aktivitas Terbaru
          _buildPendingOrdersCard(),

          const SizedBox(height: 24),
          _buildEsgImpactSummary(data),
        ],
      ),
    );
  }

  Widget _buildHeader(String companyName) {
    return Row(
      children: [
        Image.asset(
          'lib/assets/recovera-logo-horizontal.png',
          width: 72,
          height: 40,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, $companyName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bersama kita memulihkan nilai pangan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.slateText,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifikasi',
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationListScreen()),
            );
            _loadUnreadNotificationCount();
          },
          icon: Stack(
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.primary,
              ),
              if (_unreadNotificationCount > 0)
                const Positioned(
                  right: 0,
                  top: 0,
                  child: CircleAvatar(radius: 4, backgroundColor: Colors.red),
                ),
            ],
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

    final expiringCount = data.nearExpiryListings
        .where((item) => item.daysRemaining <= 7)
        .length;
    Widget row(_BentoCard first, _BentoCard second) => Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
    return Column(
      children: [
        row(
          _BentoCard(
            label: 'Stok Aktif',
            value: activeCount.toString(),
            subtitle: calculatePercent(activeCount, prevMonthActive),
            icon: Icons.inventory,
            color: AppColors.primary,
            bgColor: Colors.white,
          ),
          _BentoCard(
            label: 'Transaksi Bulan Ini',
            value: currentMonthOrders.toString(),
            subtitle: calculatePercent(currentMonthOrders, prevMonthOrders),
            icon: Icons.receipt_long,
            color: const Color(0xFF10B981),
            bgColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        row(
          _BentoCard(
            label: 'Segera Kedaluwarsa',
            value: '$expiringCount',
            subtitle: '7 hari atau kurang',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFD97706),
            bgColor: Colors.white,
          ),
          _BentoCard(
            label: 'Sertifikat ESG',
            value: '${data.esgCertificateCount}',
            subtitle: 'Sertifikat diterbitkan',
            icon: Icons.eco_outlined,
            color: const Color(0xFF15803D),
            bgColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsBar() {
    final actions = [
      (
        Icons.add_a_photo_outlined,
        'Upload Stok',
        () => const UploadStockFlowScreen(),
      ),
      (
        Icons.inventory_2_outlined,
        'Inventaris',
        () => const SellerInventoryScreen(),
      ),
      (
        Icons.eco_outlined,
        'Sertifikat ESG',
        () => const EsgCertificateListScreen(),
      ),
      (Icons.receipt_long_outlined, 'Pesanan', () => const SellerOrderScreen()),
    ];
    return Row(
      children: [
        for (final action in actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => action.$3())),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    child: Column(
                      children: [
                        Icon(action.$1, color: AppColors.primary, size: 21),
                        const SizedBox(height: 5),
                        Text(
                          action.$2,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNearExpiryCard(List<NearExpiryItem>? listings) {
    final nearExpiry = listings ?? const <NearExpiryItem>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stok Mendekati Kedaluwarsa',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.darkNavy,
            ),
          ),
          const SizedBox(height: 8),
          if (nearExpiry.isEmpty)
            Text(
              'Tidak ada stok yang mendekati kedaluwarsa.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.slateText,
              ),
            )
          else
            ...nearExpiry.map(
              (item) => _NearExpiryItemCard(
                item: item,
                badgeColor: _getBadgeColor(item.daysRemaining),
                badgeLabel: _getBadgeLabel(item.daysRemaining),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingOrdersCard() {
    final orders = _pendingOrders.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pesanan Menunggu Tindakan',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.darkNavy,
            ),
          ),
          const SizedBox(height: 10),
          if (orders.isEmpty)
            Text(
              'Tidak ada pesanan yang menunggu tindakan.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.slateText,
              ),
            )
          else
            ...orders.map(
              (order) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.productName.isEmpty
                                ? 'Listing #${order.listingId}'
                                : order.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Pembeli #${order.buyerId} · ${order.status == 'paid' ? 'Menunggu disiapkan' : 'Siap diambil'}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.slateText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await _ordersRepository.updateOrderStatus(
                            order.id,
                            order.status == 'paid'
                                ? 'in_progress'
                                : 'completed',
                          );
                          await _loadData();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Status pesanan gagal diperbarui: $e',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        order.status == 'paid' ? 'Siapkan' : 'Selesaikan',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_pendingOrders.length > 5)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SellerOrderScreen()),
                ),
                child: const Text('Lihat semua'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEsgImpactSummary(SellerDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_outlined, color: Color(0xFF15803D), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.totalCarbonSaved.toStringAsFixed(1)} kg CO₂e diselamatkan',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF166534),
                  ),
                ),
                Text(
                  '${data.esgCertificateCount} sertifikat ESG',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EsgCertificateListScreen(),
              ),
            ),
            child: const Text('Lihat Sertifikat'),
          ),
        ],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatbotFab() {
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
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ChatbotScreen()));
        },
        backgroundColor: AppColors.primary,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.smart_toy_rounded,
          color: AppColors.white,
          size: 26,
        ),
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

  const _BentoCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Icon(Icons.local_drink_rounded, size: 24, color: badgeColor),
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


/// Custom Clipper untuk gelombang header bawah (disamakan dengan Buyer HomeScreen)
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 24);
    path.cubicTo(
      size.width * 0.30,
      size.height + 6,
      size.width * 0.65,
      size.height - 32,
      size.width,
      size.height - 12,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Custom Clipper untuk aksen gelombang sekunder di latar belakang header
class _HeaderWaveBackdropClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 14);
    path.cubicTo(
      size.width * 0.35,
      size.height + 14,
      size.width * 0.70,
      size.height - 20,
      size.width,
      size.height - 6,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
