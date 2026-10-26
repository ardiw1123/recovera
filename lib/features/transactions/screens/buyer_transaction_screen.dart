import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/order_repository.dart';
import '../data/sample_transaction_orders.dart';
import '../models/transaction_order_model.dart';
import '../widgets/order_tracking_compass_sheet.dart';

/// Halaman Riwayat Transaksi Khusus Pembeli (Buyer POV)
/// Menampilkan daftar pesanan, status alur pick-up mandiri, batas waktu penjemputan,
/// dan integrasi pelacakan kompas tanpa fitur rating & tanpa toggle role.
class BuyerTransactionScreen extends StatefulWidget {
  const BuyerTransactionScreen({
    super.key,
    this.orderRepository,
  });

  final OrderRepository? orderRepository;

  @override
  State<BuyerTransactionScreen> createState() => _BuyerTransactionScreenState();
}

class _BuyerTransactionScreenState extends State<BuyerTransactionScreen> {
  late final OrderRepository _orderRepository;

  // Daftar pesanan pembeli
  List<TransactionOrder> _orderList = [];
  bool _isLoading = false;

  // Filter status aktif ('all', 'active', 'completed', 'cancelled')
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _orderRepository = widget.orderRepository ?? OrderRepository();
    _loadBuyerOrders();
  }

  /// Memuat data pesanan pembeli dari lokal SQLite atau sampel data realistis
  Future<void> _loadBuyerOrders() async {
    setState(() => _isLoading = true);
    try {
      final cachedList = await _orderRepository.getOrders(forceRefresh: true);
      final mappedList = cachedList
          .map((item) => TransactionOrder.fromCachedOrder(item))
          .toList();

      // Tambahkan dummyBuyerOrders jika belum ada, agar riwayat tetap kaya
      final existingIds = mappedList.map((e) => e.id).toSet();
      for (final dummy in dummyBuyerOrders) {
        if (!existingIds.contains(dummy.id)) {
          mappedList.add(dummy);
        }
      }

      if (mounted) {
        setState(() {
          _orderList = mappedList;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _orderList = List<TransactionOrder>.from(dummyBuyerOrders);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Memperbarui status pesanan lokal & sinkron ke SQLite
  void _updateOrderStatus(TransactionOrder targetOrder, String newStatus) async {
    setState(() {
      final index = _orderList.indexWhere((order) => order.id == targetOrder.id);
      if (index != -1) {
        _orderList[index] = _orderList[index].copyWith(status: newStatus);
      }
    });

    try {
      await _orderRepository.cacheOrder(
        targetOrder.copyWith(status: newStatus).toCachedOrder(),
      );
    } catch (_) {}
  }

  /// Format nominal mata uang Rupiah tanpa selector valuta asing
  String _formatCurrencyRupiah(double amount) {
    final integerString = amount.toInt().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < integerString.length; i++) {
      if (i > 0 && (integerString.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(integerString[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  /// Filter daftar pesanan berdasarkan tab yang dipilih
  List<TransactionOrder> get _filteredOrders {
    if (_selectedStatusFilter == 'active') {
      return _orderList
          .where((order) => order.status == 'in_progress' || order.status == 'paid')
          .toList();
    } else if (_selectedStatusFilter == 'completed') {
      return _orderList.where((order) => order.status == 'completed').toList();
    } else if (_selectedStatusFilter == 'cancelled') {
      return _orderList.where((order) => order.status == 'cancelled').toList();
    }
    return _orderList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadBuyerOrders,
        color: AppColors.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContentList(),
      ),
    );
  }

  /// AppBar khusus Pembeli dengan tema biru HomeScreen
  PreferredSizeWidget _buildAppBar() {
    final canPop = Navigator.canPop(context);
    return AppBar(
      elevation: 0,
      centerTitle: false,
      titleSpacing: canPop ? 0 : 16,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: Container(
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
      ),
      backgroundColor: AppColors.primary,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Riwayat Transaksi',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: null,
    );
  }

  /// Konten utama riwayat transaksi pembeli
  Widget _buildContentList() {
    final displayOrders = _filteredOrders;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Judul & Subtitle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riwayat Transaksi',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF03045E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Manajemen pesanan & batch B2B',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // SQLite Offline/Sync Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: Color(0xFF0284C7),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Menampilkan data lokal (SQLite cached_orders) • Otomatis sinkron',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0369A1),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tab Filter Status
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Semua',
                isSelected: _selectedStatusFilter == 'all',
                onTap: () => setState(() => _selectedStatusFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label:
                    'Aktif (${_orderList.where((order) => order.status == 'in_progress' || order.status == 'paid').length})',
                isSelected: _selectedStatusFilter == 'active',
                onTap: () => setState(() => _selectedStatusFilter = 'active'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label:
                    'Selesai (${_orderList.where((order) => order.status == 'completed').length})',
                isSelected: _selectedStatusFilter == 'completed',
                onTap: () => setState(() => _selectedStatusFilter = 'completed'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Dibatalkan',
                isSelected: _selectedStatusFilter == 'cancelled',
                onTap: () => setState(() => _selectedStatusFilter = 'cancelled'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Daftar Kartu Pesanan
        if (displayOrders.isEmpty)
          _buildEmptyState()
        else
          ...displayOrders.map((order) => _buildBuyerOrderCard(order)),
      ],
    );
  }

  /// Chip filter tab
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  /// Kartu pesanan pembeli
  Widget _buildBuyerOrderCard(TransactionOrder order) {
    final isReadyForPickup = order.status == 'in_progress';
    final isWaiting = order.status == 'paid';
    final isCompleted = order.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nama Mitra & Badge Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          order.partnerName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (order.isVerifiedPartner) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                      ],
                      if (order.distanceKm != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• ${order.distanceKm!.toStringAsFixed(1)} km',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusPill(order.status),
              ],
            ),
            const SizedBox(height: 4),

            // Waktu Transaksi & Kode Order
            Text(
              '24 Okt 2026, 14:30 WIB • ID: ${order.orderCode}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 12),

            // Baris Rincian Produk
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    order.imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 64,
                      height: 64,
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productName,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.unit,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.qr_code_2_rounded,
                              size: 12,
                              color: Color(0xFF475569),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              order.batchNumber,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Baris Total Tagihan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Tagihan:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  _formatCurrencyRupiah(order.totalPrice),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF03045E),
                  ),
                ),
              ],
            ),

            // Aksi Kontekstual Berdasarkan Status
            if (isReadyForPickup) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Color(0xFFD97706),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⏱️ Batas Ambil: 25 Okt 2026, 21:00 WIB',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                          Text(
                            'Sisa waktu 6 jam. Alokasi batch akan dilepas otomatis bila lewat batas.',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tombol Buka Pelacakan & Kompas Mandiri
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.location_on_rounded, size: 18),
                  label: Text(
                    'Petunjuk Lokasi & Pengambilan Gudang',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    OrderTrackingCompassSheet.show(
                      context,
                      order: order,
                      onStatusUpdated: (newStatus) {
                        _updateOrderStatus(order, newStatus);
                      },
                    );
                  },
                ),
              ),
            ] else if (isWaiting) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Hubungi Seller',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Menghubungi layanan pelanggan ${order.partnerName}...',
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Rincian Faktur',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => _showInvoiceDialog(order),
                    ),
                  ),
                ],
              ),
            ] else if (isCompleted) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Selesai via Verifikasi QR Gudang',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showInvoiceDialog(order),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Rincian Faktur',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Badge status pesanan
  Widget _buildStatusPill(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'paid':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = 'Menunggu Diproses';
        break;
      case 'in_progress':
      case 'picked_up':
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0369A1);
        label = 'Siap Diambil';
        break;
      case 'completed':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        label = 'Selesai';
        break;
      case 'cancelled':
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'Dibatalkan';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  /// Tampilan ketika tidak ada pesanan
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 32,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada transaksi',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Belum ada riwayat transaksi pada filter ini.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Dialog modal faktur transaksi
  void _showInvoiceDialog(TransactionOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Faktur Transaksi B2B',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  _buildStatusPill(order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${order.orderCode} • Transaksi Resmi Recovera',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              const Divider(height: 24),
              _buildInvoiceLine('Produk', order.productName),
              _buildInvoiceLine('Batch Number', order.batchNumber),
              _buildInvoiceLine('Jumlah / Qty', order.unit),
              _buildInvoiceLine('Harga Satuan', _formatCurrencyRupiah(order.unitPrice)),
              _buildInvoiceLine('Biaya Penanganan Platform', 'Rp 0 (Subsidi B2B)'),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Pembayaran',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    _formatCurrencyRupiah(order.totalPrice),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Tutup Faktur',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoiceLine(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
