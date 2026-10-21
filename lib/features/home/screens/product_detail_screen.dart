import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cached_order_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/listing_repository.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../data/services/listing_api_service.dart';
import '../../../data/services/order_api_service.dart';
import '../models/product_model.dart';

/// Screen detail produk dan eksekusi pembelian bagi akun Buyer
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    this.listing,
    this.listingId,
    this.listingRepository,
    this.orderRepository,
  });

  final Listing? listing;
  final int? listingId;
  final ListingRepository? listingRepository;
  final OrderRepository? orderRepository;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ListingRepository _listingRepository;
  late final OrderRepository _orderRepository;

  Listing? _listing;
  bool _isLoading = false;
  String? _errorMessage;
  int _selectedQty = 1;
  bool _isPurchasing = false;
  String _selectedCurrency = 'IDR'; // 'IDR', 'USD', 'EUR', 'GBP'
  String _selectedTimezone = 'WIB';  // 'WIB', 'WITA', 'WIT', 'London'

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    _listingRepository = widget.listingRepository ??
        ListingRepository(remoteClient: ListingApiService(client: client));
    _orderRepository = widget.orderRepository ??
        OrderRepository(remoteClient: OrderApiService(client: client));

    if (widget.listing != null) {
      _listing = widget.listing;
    } else if (widget.listingId != null) {
      _loadListingDetail(widget.listingId!);
    }
  }

  Future<void> _loadListingDetail(int id) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cachedModel = await _listingRepository.getListingById(id, forceRefresh: true);
      if (mounted) {
        if (cachedModel != null) {
          setState(() {
            _listing = Listing.fromCachedModel(cachedModel);
          });
        } else {
          setState(() {
            _errorMessage = 'Produk tidak ditemukan.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat detail produk: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onBuyNowTapped() async {
    final listing = _listing;
    if (listing == null) return;

    // Cek Role Guard: Seller tidak boleh membeli atau mengakses alur beli
    if (AuthRepository.instance.isSeller) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Akses ditolak: Akun penjual tidak dapat membeli produk.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Tampilkan lembar konfirmasi pemesanan
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildOrderConfirmationSheet(ctx, listing),
    );

    if (confirmed == true) {
      await _executePurchase(listing);
    }
  }

  Future<void> _executePurchase(Listing listing) async {
    setState(() => _isPurchasing = true);

    try {
      final order = await _orderRepository.buyListing(
        listing.id,
        qty: _selectedQty,
        biometricVerified: true,
      );

      if (mounted) {
        _showOrderSuccessDialog(order, listing);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyelesaikan pembelian: $e',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  void _showOrderSuccessDialog(CachedOrderModel order, Listing listing) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pembelian Berhasil!',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pesanan likuidasi pangan Anda telah dicatat oleh sistem Recovera.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _dialogRow('ID Pesanan', '#${order.id}'),
                    const SizedBox(height: 6),
                    _dialogRow('Produk', listing.productName),
                    const SizedBox(height: 6),
                    _dialogRow('Jumlah', '$_selectedQty ${listing.defaultUnit}'),
                    const SizedBox(height: 6),
                    _dialogRow('Total Harga', 'Rp ${_formatPrice(order.totalPrice)}'),
                    const SizedBox(height: 6),
                    _dialogRow('Status', order.status.toUpperCase(), isHighlight: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Silakan ambil barang di gudang ${listing.companyName} (${listing.city}) dengan menunjukkan bukti pesanan ini.',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              key: const Key('btn_order_success_confirm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: Text(
                'Selesai',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight ? const Color(0xFF10B981) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderConfirmationSheet(BuildContext ctx, Listing listing) {
    final subtotal = listing.currentPrice * _selectedQty;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Konfirmasi Pembelian',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Pastikan kuantitas dan rincian pemesanan Anda sudah sesuai.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _dialogRow('Produk', listing.productName),
                const SizedBox(height: 6),
                _dialogRow('Distributor', listing.companyName),
                const SizedBox(height: 6),
                _dialogRow('Kuantitas', '$_selectedQty ${listing.defaultUnit}'),
                const SizedBox(height: 6),
                _dialogRow('Harga Satuan', 'Rp ${_formatPrice(listing.currentPrice)}'),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Pembayaran',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Rp ${_formatPrice(subtotal)}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Batal', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const Key('btn_confirm_purchase_sheet'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Konfirmasi Beli',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Role Guard: Seller restriction ───────────────────────────────────────
    if (AuthRepository.instance.isSeller) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Detail Produk',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_outlined, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Akses Dibatasi',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Akun penjual tidak memiliki izin untuk mengakses halaman detail pembelian produk.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.slateText),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _listing == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Produk'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Produk tidak ditemukan',
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final listing = _listing!;
    final isUrgent = listing.effectiveDaysToExpiry <= 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Detail Produk',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Image & Badges ──────────────────────────────────────────
            _buildHeroImage(listing),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Shelf Life Warning Badge ───────────────────────────────
                  _buildShelfLifeBanner(listing, isUrgent),
                  const SizedBox(height: 16),

                  // ── Product Title & Brand ─────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: listing.category.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          listing.category.label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: listing.category.color,
                          ),
                        ),
                      ),
                      if (listing.brand != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•  ${listing.brand!}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.productName,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Dutch Auction Indicator ───────────────────────────────
                  if (listing.isLiveDutch) _buildDutchAuctionBanner(listing),
                  const SizedBox(height: 14),

                  // ── Pricing Breakdown & Currency Reference ────────────────
                  _buildPricingCard(listing),
                  const SizedBox(height: 16),

                  // ── Quantity & Stock Selector ──────────────────────────────
                  _buildQuantitySelector(listing),
                  const SizedBox(height: 16),

                  // ── Verified Seller Card ──────────────────────────────────
                  _buildVerifiedSellerCard(listing),
                  const SizedBox(height: 16),

                  // ── Full Product Specifications ───────────────────────────
                  _buildFullSpecifications(listing),
                  const SizedBox(height: 16),

                  // ── Zero-Waste ESG Guarantee ───────────────────────────────
                  _buildEsgGuaranteeCard(),
                  const SizedBox(height: 80), // Padding untuk sticky bottom bar
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildStickyPurchaseBar(listing),
    );
  }

  // ── Hero Image with Badges ────────────────────────────────────────────────
  Widget _buildHeroImage(Listing listing) {
    return Container(
      width: double.infinity,
      height: 250,
      color: Colors.white,
      child: Stack(
        children: [
          Hero(
            tag: 'product_image_${listing.id}',
            child: SizedBox(
              width: double.infinity,
              height: 250,
              child: listing.imageUrl != null
                  ? Image.network(
                      listing.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackHeroImage(listing),
                    )
                  : _buildFallbackHeroImage(listing),
            ),
          ),
          // Badges Overlay
          Positioned(
            top: 16,
            left: 16,
            child: Row(
              children: [
                // Proximity Match Badge
                Container(
                  key: const Key('detail_match_score_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.radar_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        listing.matchScorePercentage,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Discount Badge
                Container(
                  key: const Key('detail_discount_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    '-${listing.effectiveDiscountPercent}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Storage condition badge
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: listing.storageType == 'frozen'
                    ? const Color(0xFF0891B2)
                    : (listing.storageType == 'chilled' ? const Color(0xFF0284C7) : const Color(0xFF475569)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    listing.storageType == 'frozen'
                        ? Icons.ac_unit_rounded
                        : (listing.storageType == 'chilled' ? Icons.thermostat_rounded : Icons.inventory_2_outlined),
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    listing.storageType.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackHeroImage(Listing listing) {
    return Container(
      color: listing.category.color.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          listing.category.icon,
          size: 72,
          color: listing.category.color.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ── Shelf Life Warning Banner ─────────────────────────────────────────────
  Widget _buildShelfLifeBanner(Listing listing, bool isUrgent) {
    final bgColor = isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final borderColor = isUrgent ? const Color(0xFFFECACA) : const Color(0xFFFDE68A);
    final textColor = isUrgent ? const Color(0xFFDC2626) : const Color(0xFFB45309);

    return Container(
      key: const Key('detail_shelf_life_warning'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.warning_rounded : Icons.timer_outlined,
            color: textColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sisa ${listing.effectiveDaysToExpiry} Hari Sebelum Kedaluwarsa',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kedaluwarsa: ${_formatDate(listing.expiryDate)} (Batch: ${listing.batchNumber})',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Dutch Auction Banner & Konversi 4 Zona Waktu (US-10 / PB-063) ──────────
  Widget _buildDutchAuctionBanner(Listing listing) {
    final now = DateTime.now();
    final interval = listing.dropIntervalMinutes > 0 ? listing.dropIntervalMinutes : 15;
    final nextDropTime = now.add(Duration(minutes: interval));

    final tzMap = {
      'WIB': {'label': 'WIB (UTC+7)', 'offset': 7},
      'WITA': {'label': 'WITA (UTC+8)', 'offset': 8},
      'WIT': {'label': 'WIT (UTC+9)', 'offset': 9},
      'London': {'label': 'London (GMT)', 'offset': 0},
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.05),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF0284C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trending_down_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lelang Dutch Aktif',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0369A1),
                      ),
                    ),
                    Text(
                      'Harga turun otomatis berkala setiap $interval menit (${listing.dropPercentage}%). Amankan stok sebelum dibeli mitra lain!',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF0284C7),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0F2FE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                        Text(
                          'JADWAL DROP & WAKTU LELANG',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0369A1),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '4 Zona Waktu',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Zona Waktu Selector Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: tzMap.keys.map((tzKey) {
                      final isSelected = _selectedTimezone == tzKey;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selected: isSelected,
                          label: Text(
                            tzMap[tzKey]!['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF0369A1),
                            ),
                          ),
                          selectedColor: const Color(0xFF0284C7),
                          backgroundColor: const Color(0xFFF0F9FF),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD),
                          ),
                          onSelected: (_) => setState(() => _selectedTimezone = tzKey),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                // Waktu Terpilih Detail
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Penurunan Harga Berikutnya:',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      Text(
                        _formatTimeInZone(nextDropTime, _selectedTimezone),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Ringkasan 4 zona waktu sekaligus
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: tzMap.entries.map((entry) {
                    final tz = entry.key;
                    final formatted = _formatTimeShort(nextDropTime, tz);
                    final isHighlighted = tz == _selectedTimezone;
                    return Column(
                      children: [
                        Text(
                          tz,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isHighlighted ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          formatted,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
                            color: isHighlighted ? const Color(0xFF0284C7) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Pricing Breakdown & Konversi Multi-Mata Uang (US-09 / PB-062) ──────────
  Widget _buildPricingCard(Listing listing) {
    final currencies = [
      {'code': 'IDR', 'symbol': 'Rp', 'name': 'Rupiah', 'rate': 1.0},
      {'code': 'USD', 'symbol': '\$', 'name': 'Dolar AS', 'rate': 15800.0},
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro', 'rate': 17200.0},
      {'code': 'GBP', 'symbol': '£', 'name': 'Pound', 'rate': 20000.0},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                'HARGA LIKUIDASI SAAT INI',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Hemat ${listing.effectiveDiscountPercent}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Price Display in Selected Currency
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatPriceInCurrency(listing.currentPrice, _selectedCurrency),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${listing.defaultUnit}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatPriceInCurrency(listing.normalPrice, _selectedCurrency),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Currency Switcher Chips
          Text(
            'PILIH MATA UANG (VALAS EKSPOR/IMPOR):',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: currencies.map((c) {
                final code = c['code'] as String;
                final symbol = c['symbol'] as String;
                final isSelected = _selectedCurrency == code;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selected: isSelected,
                    avatar: Text(
                      symbol,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : AppColors.primary,
                      ),
                    ),
                    label: Text(
                      code,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    selectedColor: AppColors.primary,
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                    ),
                    onSelected: (_) => setState(() => _selectedCurrency = code),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          // Info Kurs Acuan
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.currency_exchange_rounded, size: 13, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Kurs Acuan Valas (B2B Recovera):',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '1 USD = Rp 15.800  •  1 EUR = Rp 17.200  •  1 GBP = Rp 20.000',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_selectedCurrency != 'IDR') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Rumus: Rp ${_formatPrice(listing.currentPrice)} ÷ ${_getRate(_selectedCurrency).toInt()} = ${_formatPriceInCurrency(listing.currentPrice, _selectedCurrency)}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quantity & Stock Selector ─────────────────────────────────────────────
  Widget _buildQuantitySelector(Listing listing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kuantitas Pembelian',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tersedia: ${listing.qty} ${listing.defaultUnit}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  key: const Key('btn_qty_decrease'),
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: _selectedQty > 1
                      ? () => setState(() => _selectedQty--)
                      : null,
                ),
                Text(
                  '$_selectedQty',
                  key: const Key('text_qty_value'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  key: const Key('btn_qty_increase'),
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: _selectedQty < listing.qty
                      ? () => setState(() => _selectedQty++)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Verified Seller Card ──────────────────────────────────────────────────
  Widget _buildVerifiedSellerCard(Listing listing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Text(
                'Distributor Terverifikasi',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            listing.companyName,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Gudang di ${listing.city} • ${listing.distanceText} dari lokasi Anda',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Koordinat: ${listing.warehouseLat.toStringAsFixed(4)}, ${listing.warehouseLng.toStringAsFixed(4)}',
            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ── Full Product Specifications ───────────────────────────────────────────
  Widget _buildFullSpecifications(Listing listing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spesifikasi Produk Pangan',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          _specRow('Kategori', listing.category.label),
          _specRow('Kondisi Simpan', listing.storageType),
          _specRow('Satuan Unit', listing.defaultUnit),
          _specRow('Nomor Batch', listing.batchNumber),
          _specRow('Tanggal Kedaluwarsa', _formatDate(listing.expiryDate)),
          _specRow('Mulai Lelang', _formatDate(listing.auctionStartAt)),
          _specRow('Status Listing', listing.status.toUpperCase(), isLast: true),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Container(height: 1, color: const Color(0xFFF1F5F9)),
      ],
    );
  }

  // ── Zero-Waste ESG Guarantee ───────────────────────────────────────────────
  Widget _buildEsgGuaranteeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_rounded, color: Color(0xFF059669), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jaminan Likuidasi & Zero-Waste ESG',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stok terlindungi kepatuhan audit. Jika belum terjual pada H-14, stok dialihkan ke Food Bank mitra dan dicatat sertifikat ESG.',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF047857),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sticky Purchase Bar ───────────────────────────────────────────────────
  Widget _buildStickyPurchaseBar(Listing listing) {
    final subtotal = listing.currentPrice * _selectedQty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Pembelian',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Rp ${_formatPrice(subtotal)}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  key: const Key('btn_buy_now'),
                  onPressed: _isPurchasing ? null : _onBuyNowTapped,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: _isPurchasing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Beli Sekarang',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    final str = price.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return '$d/$m/$y';
  }

  double _getRate(String currency) {
    switch (currency) {
      case 'USD':
        return 15800.0;
      case 'EUR':
        return 17200.0;
      case 'GBP':
        return 20000.0;
      case 'IDR':
      default:
        return 1.0;
    }
  }

  String _formatPriceInCurrency(double priceIdr, String currency) {
    switch (currency) {
      case 'USD':
        return '\$${(priceIdr / 15800.0).toStringAsFixed(2)} USD';
      case 'EUR':
        return '€${(priceIdr / 17200.0).toStringAsFixed(2)} EUR';
      case 'GBP':
        return '£${(priceIdr / 20000.0).toStringAsFixed(2)} GBP';
      case 'IDR':
      default:
        return 'Rp ${_formatPrice(priceIdr)}';
    }
  }

  String _formatTimeInZone(DateTime dt, String zone) {
    final utc = dt.toUtc();
    switch (zone) {
      case 'WITA':
        final target = utc.add(const Duration(hours: 8));
        return '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')} WITA (UTC+8)';
      case 'WIT':
        final target = utc.add(const Duration(hours: 9));
        return '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')} WIT (UTC+9)';
      case 'London':
        final target = utc;
        return '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')} GMT (London, UTC+0)';
      case 'WIB':
      default:
        final target = utc.add(const Duration(hours: 7));
        return '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')} WIB (UTC+7)';
    }
  }

  String _formatTimeShort(DateTime dt, String zone) {
    final utc = dt.toUtc();
    switch (zone) {
      case 'WITA':
        final target = utc.add(const Duration(hours: 8));
        return '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';
      case 'WIT':
        final target = utc.add(const Duration(hours: 9));
        return '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';
      case 'London':
        final target = utc;
        return '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';
      case 'WIB':
      default:
        final target = utc.add(const Duration(hours: 7));
        return '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';
    }
  }
}
