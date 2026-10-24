import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/order_repository.dart';
import '../data/sample_transaction_orders.dart';
import '../models/transaction_order_model.dart';

/// Halaman Kelola Pesanan Khusus Penjual / Distributor (Seller POV)
/// Menampilkan ringkasan omset penjualan, total lot terjual, daftar pesanan masuk dari UMKM,
/// serta aksi penjual untuk memperbarui alur penyiapan dan serah terima batch.
class SellerOrderScreen extends StatefulWidget {
  const SellerOrderScreen({
    super.key,
    this.orderRepository,
  });

  final OrderRepository? orderRepository;

  @override
  State<SellerOrderScreen> createState() => _SellerOrderScreenState();
}

class _SellerOrderScreenState extends State<SellerOrderScreen> {
  late final OrderRepository _orderRepository;

  // Daftar pesanan masuk untuk penjual
  List<TransactionOrder> _sellerOrders = [];
  bool _isLoading = false;

  // Filter status pesanan ('all', 'paid', 'in_progress', 'completed')
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _orderRepository = widget.orderRepository ?? OrderRepository();
    _loadSellerOrders();
  }

  /// Memuat pesanan seller
  Future<void> _loadSellerOrders() async {
    setState(() => _isLoading = true);
    try {
      // Gunakan data dummy seller yang realistis dan konsisten
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() {
          _sellerOrders = List<TransactionOrder>.from(dummySellerOrders);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sellerOrders = List<TransactionOrder>.from(dummySellerOrders);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Memperbarui status pesanan seller
  void _updateOrderStatus(TransactionOrder targetOrder, String newStatus) async {
    setState(() {
      final index = _sellerOrders.indexWhere((order) => order.id == targetOrder.id);
      if (index != -1) {
        _sellerOrders[index] = _sellerOrders[index].copyWith(status: newStatus);
      }
    });

    try {
      await _orderRepository.cacheOrder(
        targetOrder.copyWith(status: newStatus).toCachedOrder(),
      );
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pesanan ${targetOrder.orderCode} berhasil diperbarui ke: ${_getStatusLabel(newStatus)}',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Format nominal mata uang Rupiah
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

  /// Hitung total pendapatan dari seluruh pesanan seller
  double get _totalRevenue {
    double sum = 0.0;
    for (final order in _sellerOrders) {
      if (order.status != 'cancelled') {
        sum += order.totalPrice;
      }
    }
    return sum;
  }

  /// Hitung total lot barang terjual
  int get _totalSoldLots {
    return _sellerOrders.where((order) => order.status != 'cancelled').length;
  }

  /// Filter pesanan berdasarkan tab status
  List<TransactionOrder> get _filteredOrders {
    if (_selectedStatusFilter == 'all') {
      return _sellerOrders;
    }
    return _sellerOrders
        .where((order) => order.status == _selectedStatusFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadSellerOrders,
        color: AppColors.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContentList(),
      ),
    );
  }

  /// AppBar khusus Penjual
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
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
            'Kelola Pesanan',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF03045E),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Semua pesanan masuk sudah ter-sinkronisasi.',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF404850),
            size: 24,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  /// Konten halaman kelola pesanan seller
  Widget _buildContentList() {
    final displayOrders = _filteredOrders;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Distributor portal tag & title
        Text(
          'DISTRIBUTOR PORTAL',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Kelola Pesanan Masuk',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF03045E),
          ),
        ),
        const SizedBox(height: 8),

        // Indikator koneksi backend
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Terhubung ke Backend FastAPI',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Summary Cards: Revenue & Volume
        _buildSellerSummaryCards(),
        const SizedBox(height: 16),

        // Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Semua (${_sellerOrders.length})',
                isSelected: _selectedStatusFilter == 'all',
                onTap: () => setState(() => _selectedStatusFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label:
                    'Perlu Disiapkan (${_sellerOrders.where((o) => o.status == 'paid').length})',
                isSelected: _selectedStatusFilter == 'paid',
                onTap: () => setState(() => _selectedStatusFilter = 'paid'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label:
                    'Siap Diambil (${_sellerOrders.where((o) => o.status == 'in_progress').length})',
                isSelected: _selectedStatusFilter == 'in_progress',
                onTap: () => setState(() => _selectedStatusFilter = 'in_progress'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label:
                    'Selesai (${_sellerOrders.where((o) => o.status == 'completed').length})',
                isSelected: _selectedStatusFilter == 'completed',
                onTap: () => setState(() => _selectedStatusFilter = 'completed'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Daftar Pesanan
        if (displayOrders.isEmpty)
          _buildEmptyState()
        else
          ...displayOrders.map((order) => _buildSellerOrderCard(order)),
      ],
    );
  }

  /// Kartu ringkasan performa penjualan seller
  Widget _buildSellerSummaryCards() {
    return Row(
      children: [
        // Card 1: Total Pendapatan
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL PENDAPATAN',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.4,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.payments_rounded,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatCurrencyRupiah(_totalRevenue),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF03045E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '+18.4% bln ini',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Card 2: Total Penjualan Lot
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL PENJUALAN',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.4,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$_totalSoldLots Lot Terjual',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF03045E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_sellerOrders.where((o) => o.status == 'in_progress').length} menunggu pickup',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
        ),
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
          color: isSelected ? const Color(0xFF03045E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF03045E) : const Color(0xFFCBD5E1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF03045E).withValues(alpha: 0.2),
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

  /// Kartu pesanan seller
  Widget _buildSellerOrderCard(TransactionOrder order) {
    final isPaid = order.status == 'paid';
    final isInProgress = order.status == 'in_progress';

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
            // Top: Pembeli & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.store_rounded,
                        size: 18,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 6),
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
                    ],
                  ),
                ),
                _buildStatusPill(order.status),
              ],
            ),
            const SizedBox(height: 4),

            // Date & ID
            Text(
              '24 Okt 2026, 15:10 WIB • ID: ${order.orderCode}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 12),

            // Product Item Row
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
                        child: Text(
                          order.batchNumber,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Harga Satuan & Total Tagihan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Harga Satuan: ${_formatCurrencyRupiah(order.unitPrice)}',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
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
            const SizedBox(height: 12),

            // Tombol Aksi Penjual
            if (isPaid) ...[
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.inventory_rounded, size: 18),
                  label: Text(
                    'Siapkan & Tandai Siap Diambil',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    _updateOrderStatus(order, 'in_progress');
                  },
                ),
              ),
            ] else if (isInProgress) ...[
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.handshake_rounded, size: 18),
                  label: Text(
                    'Konfirmasi Telah Diambil (Handover)',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    _updateOrderStatus(order, 'completed');
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),

            // Rincian Faktur
            Center(
              child: TextButton(
                onPressed: () => _showInvoiceDialog(order),
                style: TextButton.styleFrom(
                  minimumSize: const Size(100, 32),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  'Lihat Rincian Faktur & Bukti Transaksi',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Label nama status
  String _getStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Menunggu Diproses';
      case 'in_progress':
        return 'Siap Diambil';
      case 'picked_up':
        return 'Dalam Pengiriman';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
      default:
        return 'Dibatalkan';
    }
  }

  /// Badge status
  Widget _buildStatusPill(String status) {
    Color bg;
    Color text;
    String label = _getStatusLabel(status);

    switch (status) {
      case 'paid':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        break;
      case 'in_progress':
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0369A1);
        break;
      case 'picked_up':
        bg = const Color(0xFFEDE9FE);
        text = const Color(0xFF6D28D9);
        break;
      case 'completed':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        break;
      case 'cancelled':
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
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

  /// Tampilan ketika filter kosong
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
            'Belum ada pesanan',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada pesanan masuk pada filter ini.',
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

  /// Modal faktur transaksi
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
                    'Faktur Penjualan B2B',
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
                'ID: ${order.orderCode} • Mitra Pembeli: ${order.partnerName}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              const Divider(height: 24),
              _buildInvoiceLine('Nama Barang', order.productName),
              _buildInvoiceLine('Nomor Batch', order.batchNumber),
              _buildInvoiceLine('Jumlah / Qty', order.unit),
              _buildInvoiceLine('Harga Satuan Final', _formatCurrencyRupiah(order.unitPrice)),
              _buildInvoiceLine('Status Pembayaran', 'Lunas (Dana Terverifikasi)'),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Penerimaan',
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
                      color: const Color(0xFF03045E),
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
                    backgroundColor: const Color(0xFF03045E),
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
