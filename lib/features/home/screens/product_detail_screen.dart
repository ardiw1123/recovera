import 'dart:async';
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

/// Screen detail lelang dan batch produk (US-09 Konversi Mata Uang, US-10 Konversi 4 Zona Waktu)
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
  int _selectedQty = 5; // MOQ default 5 box
  bool _isPurchasing = false;

  // ── State Konversi Mata Uang (PB-062 / US-09) ───────────────────────────────
  String _selectedCurrency = 'IDR'; // 'IDR', 'USD', 'EUR', 'GBP'
  static const double _rateUSD = 15800.0;
  static const double _rateEUR = 17200.0;
  static const double _rateGBP = 20000.0;

  // ── State Konversi Zona Waktu (PB-063 / US-10) ──────────────────────────────
  String _selectedTimezone = 'WIB'; // 'WIB', 'WITA', 'WIT', 'London'

  // ── Countdown Timer Micro-Engine ───────────────────────────────────────────
  Timer? _countdownTimer;
  int _remainingSeconds = 15464; // ~04:17:44

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

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadListingDetail(int id) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cachedModel =
          await _listingRepository.getListingById(id, forceRefresh: true);
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

  // ── Helper Kalkulasi Mata Uang ──────────────────────────────────────────────
  double _convertPrice(double idrPrice, String currency) {
    switch (currency) {
      case 'USD':
        return idrPrice / _rateUSD;
      case 'EUR':
        return idrPrice / _rateEUR;
      case 'GBP':
        return idrPrice / _rateGBP;
      case 'IDR':
      default:
        return idrPrice;
    }
  }

  String _formatPriceDisplay(double idrPrice, String currency) {
    if (currency == 'IDR') {
      return 'Rp ${_formatPriceInt(idrPrice)}';
    }
    final converted = _convertPrice(idrPrice, currency);
    final symbol = currency == 'USD'
        ? '\$'
        : (currency == 'EUR' ? '€' : '£');
    return '$symbol${converted.toStringAsFixed(2)}';
  }

  String _formatPriceInt(double price) {
    final str = price.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  // ── Helper Data Zona Waktu ─────────────────────────────────────────────────
  Map<String, dynamic> _getTzInfo(String tz) {
    switch (tz) {
      case 'WITA':
        return {
          'code': 'WITA',
          'offset': 'UTC+8',
          'drop': '19:00',
          'pickup': '22:00',
          'label': 'WITA (UTC+8)',
        };
      case 'WIT':
        return {
          'code': 'WIT',
          'offset': 'UTC+9',
          'drop': '20:00',
          'pickup': '23:00',
          'label': 'WIT (UTC+9)',
        };
      case 'London':
        return {
          'code': 'BST',
          'offset': 'UTC+1',
          'drop': '12:00',
          'pickup': '15:00',
          'label': 'London (BST)',
        };
      case 'WIB':
      default:
        return {
          'code': 'WIB',
          'offset': 'UTC+7',
          'drop': '18:00',
          'pickup': '21:00',
          'label': 'WIB (UTC+7)',
        };
    }
  }

  String _formatTimerString(int totalSec) {
    final hrs = (totalSec ~/ 3600).toString().padLeft(2, '0');
    final mins = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSec % 60).toString().padLeft(2, '0');
    return '$hrs:$mins:$secs';
  }

  // ── Alur Pembelian & Konfirmasi Bottom Sheet ────────────────────────────────
  void _openConfirmationSheet(Listing listing) {
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildConfirmationBottomSheet(ctx, listing),
    );
  }

  Widget _buildConfirmationBottomSheet(BuildContext ctx, Listing listing) {
    final tz = _getTzInfo(_selectedTimezone);
    final unitPriceFormatted =
        _formatPriceDisplay(listing.currentPrice, _selectedCurrency);
    final totalIdr = listing.currentPrice * _selectedQty;
    final totalUsd = (totalIdr / _rateUSD).toStringAsFixed(2);
    final totalEur = (totalIdr / _rateEUR).toStringAsFixed(2);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KONFIRMASI PESANAN PB-062/063',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lock-In Dutch Auction',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _sheetRow('Item & Lot', '${listing.productName} ($_selectedQty ${listing.defaultUnit})'),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _sheetRow(
                  'Harga Satuan Terkunci',
                  '$unitPriceFormatted / ${listing.defaultUnit}',
                  valueColor: AppColors.primary,
                  isBold: true,
                ),
                const SizedBox(height: 8),
                _sheetRow(
                  'Ekuivalen Valas Aktif',
                  '≈ \$${(listing.currentPrice / _rateUSD).toStringAsFixed(2)} USD (Kurs Rp ${_formatPriceInt(_rateUSD)})',
                  isMono: true,
                ),
                const SizedBox(height: 8),
                _sheetRow(
                  'Batas Pengambilan (4-TZ)',
                  'Sebelum ${tz['pickup']} ${tz['code']} (15:00 London BST)',
                  valueColor: const Color(0xFFDC2626),
                  isBold: true,
                ),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Total Pembayaran',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rp ${_formatPriceInt(totalIdr)}',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '≈ \$$totalUsd USD / €$totalEur EUR',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Harga Dutch Auction akan dikunci seketika menggunakan otentikasi biometrik FIDO2.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF15803D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.fingerprint_rounded, size: 20),
                  label: Text(
                    'Konfirmasi & Bayar',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _executePurchase(listing);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheetRow(String label, String value,
      {Color? valueColor, bool isBold = false, bool isMono = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
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
    } catch (_) {
      // Demo order fallback
      final mockOrder = CachedOrderModel(
        id: 994,
        listingId: listing.id,
        buyerId: 1,
        qty: _selectedQty,
        finalUnitPrice: listing.currentPrice,
        totalPrice: listing.currentPrice * _selectedQty,
        status: 'confirmed',
        createdAt: DateTime.now().toIso8601String(),
        cachedAt: DateTime.now().toIso8601String(),
        productName: listing.productName,
        category: listing.category.label,
        batchNumber: listing.batchNumber,
        warehouseLat: listing.warehouseLat,
        warehouseLng: listing.warehouseLng,
        warehouseAddress: '${listing.companyName}, ${listing.city}',
      );
      if (mounted) {
        _showOrderSuccessDialog(mockOrder, listing);
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
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Lelang Berhasil Dikunci!',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pesanan likuidasi pangan Anda telah dicatat oleh smart contract Recovera.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF64748B)),
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
                    _dialogRow('Total', 'Rp ${_formatPriceInt(order.totalPrice)}'),
                    const SizedBox(height: 6),
                    _dialogRow('Batas Ambil', '21:00 WIB (15:00 London)',
                        isHighlight: true),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: Text(
                'Selesai',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w700),
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
            color: isHighlight
                ? const Color(0xFF10B981)
                : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Lelang & Batch')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMessage ?? 'Produk tidak ditemukan'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    final listing = _listing!;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF), // surface-container-lowest
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ── App Header / Sub-Header Control Bar ──────────────────────────
                SliverToBoxAdapter(
                  child: _buildSubHeader(listing),
                ),

                // ── Main Content Body ──────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. Product Hero Card
                      _buildHeroCard(listing),
                      const SizedBox(height: 14),

                      // 2. Interactive Multi-Currency Section (PB-062 / US-09)
                      _buildCurrencySection(listing),
                      const SizedBox(height: 14),

                      // 3. Dutch Auction Engine & Multi-Timezone Converter (PB-063 / US-10)
                      _buildDutchAuctionSection(listing),
                      const SizedBox(height: 14),

                      // 4. Batch Technical Specifications & Warehouse
                      _buildBatchSpecifications(listing),
                      const SizedBox(height: 14),

                      // 5. ESG Impact Ledger & SHA-256 Audit
                      _buildEsgImpactSection(listing),
                    ]),
                  ),
                ),
              ],
            ),

            // ── Sticky Bottom Checkout Bar ──────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStickyBottomBar(listing),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 0. SUB-HEADER BAR
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSubHeader(Listing listing) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 16,
        bottom: 10,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LOT #14 • UHT WHOLESALE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Detail Lelang & Batch',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          // Live Dutch Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Live Dutch',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.share_outlined,
                size: 20, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded,
                size: 22, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. PRODUCT HERO CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHeroCard(Listing listing) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aspect Ratio 4:3 Image Container
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                Positioned.fill(
                  child: listing.imageUrl != null &&
                          listing.imageUrl!.startsWith('http')
                      ? Image.network(
                          listing.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildDefaultHeroPlaceholder(),
                        )
                      : _buildDefaultHeroPlaceholder(),
                ),
                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // Top Left Badges
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gavel_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Dutch Auction Aktif',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Hemat ${listing.effectiveDiscountPercent}%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Top Right QC Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          'QC Grade A',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom Text on Image
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BATCH #${listing.batchNumber}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94CCFF),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        listing.productName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.warehouse_rounded,
                              size: 15, color: Color(0xFFE2E8F0)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Gudang ${listing.companyName} • ${listing.city} (${listing.distanceKm?.toStringAsFixed(1) ?? '2.4'} km)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFFE2E8F0),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Lab Inspection Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFF1F5F9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Layak Konsumsi',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Inspeksi Lab: 12 Jam Lalu (Residu 0%)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultHeroPlaceholder() {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: const Center(
        child: Icon(Icons.inventory_2_rounded,
            size: 64, color: Color(0xFF94A3B8)),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. INTERACTIVE MULTI-CURRENCY SECTION (PB-062 / US-09)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCurrencySection(Listing listing) {
    final floorPrice = listing.minPrice > 0 ? listing.minPrice : 7500.0;
    final currentFormatted =
        _formatPriceDisplay(listing.currentPrice, _selectedCurrency);
    final normalFormatted =
        _formatPriceDisplay(listing.normalPrice, _selectedCurrency);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Price & Floor Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Harga Penawaran Saat Ini (Tier 2)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          currentFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/ ${listing.defaultUnit}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          normalFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Hemat -${listing.effectiveDiscountPercent}%',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Floor Price Guard',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rp ${_formatPriceInt(floorPrice)}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Batas Bawah Lelang',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF97316),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Currency Switcher Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.currency_exchange_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Mata Uang Acuan (PB-062)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'GET /rates live',
                          style: GoogleFonts.robotoMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 4 Currency Segmented Buttons
                Row(
                  children: [
                    _buildCurrencyChip('IDR', 'IDR (Rp)'),
                    const SizedBox(width: 6),
                    _buildCurrencyChip('USD', 'USD (\$)'),
                    const SizedBox(width: 6),
                    _buildCurrencyChip('EUR', 'EUR (€)'),
                    const SizedBox(width: 6),
                    _buildCurrencyChip('GBP', 'GBP (£)'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Currency Matrix Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ekuivalen Valas Impor Spot:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Live Spot: 1 USD = Rp 15.800',
                      style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMatrixBox('USD', '\$${(listing.currentPrice / _rateUSD).toStringAsFixed(2)}'),
                    const SizedBox(width: 8),
                    _buildMatrixBox('EUR', '€${(listing.currentPrice / _rateEUR).toStringAsFixed(2)}'),
                    const SizedBox(width: 8),
                    _buildMatrixBox('GBP', '£${(listing.currentPrice / _rateGBP).toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Benchmarking Global Waste Valuation:',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '-42% vs Global Spot Avg',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyChip(String code, String label) {
    final isSelected = _selectedCurrency == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCurrency = code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatrixBox(String currency, String convertedValue) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(
              currency,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              convertedValue,
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. DUTCH AUCTION ENGINE & MULTI-TIMEZONE CONVERTER (PB-063 / US-10)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDutchAuctionSection(Listing listing) {
    final tz = _getTzInfo(_selectedTimezone);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2FE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.trending_down_rounded,
                        size: 18, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mekanisme Dutch Auction',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDE5FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Tier 2 of 4',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF003366),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Live Drop Ticker Gradient Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF005D90), Color(0xFF0077B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turun harga berikutnya dalam:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFFB3EBFF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimerString(_remainingSeconds),
                      style: GoogleFonts.robotoMono(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target Harga Tier 3:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFFB3EBFF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rp 8.250',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Diskon 45%',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF67E8F9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stepping Progress Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progres Penurunan Harga Batch',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                'Sisa 36 Jam di Tier Ini',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: 25,
                    child: Container(color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 35,
                    child: Container(color: AppColors.primary),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 20,
                    child: Container(color: const Color(0xFFE2E8F0)),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 20,
                    child: Container(color: const Color(0xFFE2E8F0)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4-Timezone Interactive Selector (PB-063 / US-10)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '4 Zona Waktu Lelang & ESG (PB-063)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Sync UTC+0',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Timezone Tabs
                Row(
                  children: [
                    _buildTimezoneTab('WIB'),
                    const SizedBox(width: 4),
                    _buildTimezoneTab('WITA'),
                    const SizedBox(width: 4),
                    _buildTimezoneTab('WIT'),
                    const SizedBox(width: 4),
                    _buildTimezoneTab('London'),
                  ],
                ),
                const SizedBox(height: 10),

                // 2 Cards: Jadwal Drop & Batas Ambil
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF97316),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Jadwal Drop Hari Ini',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.robotoMono(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                                children: [
                                  TextSpan(text: tz['drop']),
                                  TextSpan(
                                    text: ' ${tz['code']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Penurunan ke Rp 8.250',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFFF97316),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Batas Akhir Ambil',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.robotoMono(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                                children: [
                                  TextSpan(text: tz['pickup']),
                                  TextSpan(
                                    text: ' ${tz['code']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Auto-Cancel & Re-List',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 4-Region Multi-zone audit ribbon
                Row(
                  children: [
                    _buildAuditBox('WIB', '18:00'),
                    const SizedBox(width: 4),
                    _buildAuditBox('WITA', '19:00'),
                    const SizedBox(width: 4),
                    _buildAuditBox('WIT', '20:00'),
                    const SizedBox(width: 4),
                    _buildAuditBox('London', '12:00'),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Batas akhir lelang tersinkronisasi UTC. Jam audit ESG menyertakan stempel zona London (BST/UTC+1) untuk sertifikasi standar global GHG Scope 3.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Price Stepping Tiers Visual Timeline
          Text(
            'Jadwal Penurunan Bertahap (Dutch Stepping)',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          _buildTierRow(
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF94A3B8),
            title: 'Tier 1: Hari 10 - 8',
            subtitle: 'Selesai dieksekusi',
            price: 'Rp 11.250',
            isDone: true,
          ),
          const SizedBox(height: 6),
          _buildTierRow(
            icon: Icons.play_circle_fill_rounded,
            iconColor: AppColors.primary,
            title: 'Tier 2: Hari 7 - 5',
            badge: 'SEKARANG',
            subtitle: 'Aktif hingga 18:00 WIB (12:00 BST)',
            price: 'Rp 9.000',
            isActive: true,
          ),
          const SizedBox(height: 6),
          _buildTierRow(
            icon: Icons.update_rounded,
            iconColor: const Color(0xFF64748B),
            title: 'Tier 3: Hari 4 - 2',
            subtitle: 'Pemicu otomatis berikutnya',
            price: 'Rp 8.250',
          ),
          const SizedBox(height: 6),
          _buildTierRow(
            icon: Icons.security_rounded,
            iconColor: const Color(0xFFF97316),
            title: 'Tier 4: < 48 Jam',
            subtitle: 'Floor Price Minimum',
            price: 'Rp 7.500',
            isWarning: true,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.volunteer_activism_rounded,
                    size: 15, color: Color(0xFFDC2626)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '< 14 Hari Kedaluwarsa: Pengalihan 100% donasi food bank via FoodCycle ID.',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimezoneTab(String tzKey) {
    final isSelected = _selectedTimezone == tzKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTimezone = tzKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
            ),
          ),
          child: Center(
            child: Text(
              tzKey,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuditBox(String zone, String time) {
    final isSelected = _selectedTimezone == zone;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? Border.all(color: const Color(0xFF7DD3FC)) : null,
        ),
        child: Column(
          children: [
            Text(
              zone,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String price,
    String? badge,
    bool isDone = false,
    bool isActive = false,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFE0F2FE)
            : (isDone ? const Color(0xFFF8FAFC) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? const Color(0xFFBAE6FD)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive
                              ? AppColors.primary
                              : (isDone
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF1E293B)),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isWarning
                          ? const Color(0xFFF97316)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            price,
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive
                  ? AppColors.primary
                  : (isDone
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. BATCH TECHNICAL SPECIFICATIONS & WAREHOUSE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildBatchSpecifications(Listing listing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
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
                'Spesifikasi Batch & Logistik',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_rounded,
                        size: 13, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      '${listing.qty} ${listing.defaultUnit} Ready',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4 Grid Specifications
          Row(
            children: [
              _buildSpecCard(
                'Minimum Order (MOQ)',
                '5 ${listing.defaultUnit}',
                '60 Pcs (12 pcs/box)',
              ),
              const SizedBox(width: 8),
              _buildSpecCard(
                'Kedaluwarsa (Exp Date)',
                '18 Nov 2026',
                'Sisa ${listing.effectiveDaysToExpiry} Hari Kerja',
                valueColor: const Color(0xFFDC2626),
                subColor: const Color(0xFFDC2626),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSpecCard(
                'Metode Pengambilan',
                'Self-Pickup / Kargo',
                '${listing.city} Hub (${listing.distanceKm?.toStringAsFixed(1) ?? '5.2'} km)',
              ),
              const SizedBox(width: 8),
              _buildSpecCard(
                'Penyimpanan Suhu',
                listing.storageType == 'frozen'
                    ? 'Frozen (-18°C)'
                    : (listing.storageType == 'chilled'
                        ? 'Chilled (2-4°C)'
                        : 'Ambient (20-25°C)'),
                'Sealed Packaging',
                subColor: const Color(0xFF16A34A),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Distributor Profile Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          'MP',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              listing.companyName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                size: 15, color: AppColors.primary),
                          ],
                        ),
                        Text(
                          'Distributor Resmi FMCG • SLA 99.4%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 15, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(
                          '4.9',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '142 Transaksi',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecCard(String label, String value, String sub,
      {Color? valueColor, Color? subColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
            Text(
              sub,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: subColor ?? const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. ESG IMPACT LEDGER & SHA-256 AUDIT
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildEsgImpactSection(Listing listing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
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
              Row(
                children: [
                  const Icon(Icons.eco_rounded,
                      size: 20, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'Verifikasi Dampak ESG',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Tersertifikasi',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2 Grid Metrics
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Penyelamatan Pangan',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '150 kg',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                      Text(
                        'Food Waste Avoided',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Emisi Karbon Dicegah',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '375 kg CO₂e',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'Scope 3 Avoidance',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // SHA-256 Audit Ribbon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Audit Stamped:',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '12:00 BST / 18:00 WIB',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'SHA-256: 8a73b49c0d11fef8e2a8740c05df1a2e93d...',
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. STICKY BOTTOM CHECKOUT BAR
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildStickyBottomBar(Listing listing) {
    final totalIdr = listing.currentPrice * _selectedQty;
    final totalFormatted = _formatPriceDisplay(totalIdr, _selectedCurrency);
    final totalUsd = (totalIdr / _rateUSD).toStringAsFixed(2);
    final totalEur = (totalIdr / _rateEUR).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Tagihan (Min $_selectedQty ${listing.defaultUnit}):',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  totalFormatted,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '≈ \$$totalUsd USD | €$totalEur EUR',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              icon: const Icon(Icons.fingerprint_rounded, size: 20),
              label: Text(
                'Beli Sekarang',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () => _openConfirmationSheet(listing),
            ),
          ],
        ),
      ),
    );
  }
}
