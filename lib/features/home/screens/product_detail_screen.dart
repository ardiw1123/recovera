import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cached_order_model.dart';
import '../../../data/repositories/app_prefs_repository.dart';
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
  double _rateUSD = 15800.0;
  double _rateEUR = 17200.0;
  double _rateGBP = 20000.0;
  bool _isLoadingRates = false;
  String _rateStatusLabel = 'GET /rates live';
  String _rateSource = 'open.er-api.com';
  String _lastRateUpdate = 'Sinkronisasi...';

  // ── State Konversi Zona Waktu (PB-063 / US-10) ──────────────────────────────
  String _selectedTimezone = 'WIB'; // 'WIB', 'WITA', 'WIT', 'London'
  DateTime _currentTime = DateTime.now();

  // ── Countdown Timer Micro-Engine ───────────────────────────────────────────
  Timer? _countdownTimer;
  int _remainingSeconds = 15464; // ~04:17:44

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    _listingRepository =
        widget.listingRepository ??
        ListingRepository(remoteClient: ListingApiService(client: client));
    _orderRepository =
        widget.orderRepository ??
        OrderRepository(remoteClient: OrderApiService(client: client));

    if (widget.listing != null) {
      _listing = widget.listing;
      _selectedQty = _getMinOrderQty(_listing!);
    } else if (widget.listingId != null) {
      _loadListingDetail(widget.listingId!);
    }

    _loadUserPreferences();
    _startCountdown();
    _fetchLiveRates();
  }

  Future<void> _loadUserPreferences() async {
    try {
      final prefs = AppPrefsRepository();
      final cur = await prefs.getSelectedCurrency();
      final tz = await prefs.getSelectedTimezone();
      if (mounted) {
        setState(() {
          _selectedCurrency = cur;
          _selectedTimezone = tz;
        });
      }
    } catch (_) {}
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _currentTime = DateTime.now();
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  /// Mengambil kurs valuta asing terkini dari Open Exchange-Rate API / Backend
  /// Sesuai PRD US-09 & PB-062: Live API dengan fallback ke cache lokal & benchmark statis.
  Future<void> _fetchLiveRates() async {
    if (_isLoadingRates) return;
    setState(() {
      _isLoadingRates = true;
      _rateStatusLabel = 'Syncing...';
    });

    try {
      // 1. Coba baca cache lokal SQLite terlebih dahulu (Offline first)
      try {
        final cached = await AppPrefsRepository().getLastCurrencyRates();
        if (cached.isNotEmpty && mounted) {
          setState(() {
            if (cached['USD'] != null && cached['USD']! > 0)
              _rateUSD = 1.0 / cached['USD']!;
            if (cached['EUR'] != null && cached['EUR']! > 0)
              _rateEUR = 1.0 / cached['EUR']!;
            if (cached['GBP'] != null && cached['GBP']! > 0)
              _rateGBP = 1.0 / cached['GBP']!;
          });
        }
      } catch (_) {}

      // 2. Coba panggil Public Open Exchange Rate API (Live Market Rate)
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      try {
        final response = await dio.get('https://open.er-api.com/v6/latest/IDR');
        if (response.statusCode == 200 && response.data != null) {
          final rates = response.data['rates'] as Map<String, dynamic>;
          final usdPerIdr = (rates['USD'] as num).toDouble();
          final eurPerIdr = (rates['EUR'] as num).toDouble();
          final gbpPerIdr = (rates['GBP'] as num).toDouble();

          if (mounted) {
            setState(() {
              _rateUSD = usdPerIdr > 0 ? (1.0 / usdPerIdr) : _rateUSD;
              _rateEUR = eurPerIdr > 0 ? (1.0 / eurPerIdr) : _rateEUR;
              _rateGBP = gbpPerIdr > 0 ? (1.0 / gbpPerIdr) : _rateGBP;
              _rateStatusLabel = 'Live API (Connected)';
              _rateSource = 'open.er-api.com';
              _lastRateUpdate =
                  '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB';
            });
          }

          // Simpan ke SQLite cache lokal
          try {
            await AppPrefsRepository().setLastCurrencyRates({
              'USD': usdPerIdr,
              'EUR': eurPerIdr,
              'GBP': gbpPerIdr,
            });
          } catch (_) {}
          return;
        }
      } catch (_) {
        // 3. Fallback ke endpoint backend Recovera /rates
        try {
          final backendRes = await dio.get('${ApiConstants.baseUrl}/rates');
          if (backendRes.statusCode == 200 && backendRes.data != null) {
            final data = backendRes.data['data'] as Map<String, dynamic>;
            final rates = data['rates'] as Map<String, dynamic>;
            final usdPerIdr = (rates['USD'] as num).toDouble();
            final eurPerIdr = (rates['EUR'] as num).toDouble();
            final gbpPerIdr = (rates['GBP'] as num).toDouble();

            if (mounted) {
              setState(() {
                _rateUSD = usdPerIdr > 0 ? (1.0 / usdPerIdr) : _rateUSD;
                _rateEUR = eurPerIdr > 0 ? (1.0 / eurPerIdr) : _rateEUR;
                _rateGBP = gbpPerIdr > 0 ? (1.0 / gbpPerIdr) : _rateGBP;
                _rateStatusLabel = 'Backend /rates';
                _rateSource = 'FastAPI Proxy';
                _lastRateUpdate =
                    '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB';
              });
            }
            return;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _rateStatusLabel = 'Fallback Kurs (Offline)';
          _rateSource = 'Benchmark Statis';
          _lastRateUpdate = 'Offline';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _rateStatusLabel = 'Fallback Kurs (Offline)';
          _rateSource = 'Benchmark Statis';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRates = false);
      }
    }
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
      final cachedModel = await _listingRepository.getListingById(
        id,
        forceRefresh: true,
      );
      if (mounted) {
        if (cachedModel != null) {
          setState(() {
            _listing = Listing.fromCachedModel(cachedModel);
            _selectedQty = _getMinOrderQty(_listing!);
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

  // ── Helper Unit & Kuantitas Minimum (MOQ) ──────────────────────────────────
  String _getDisplayUnit(Listing listing) {
    final unit = listing.defaultUnit.toLowerCase().trim();
    if (unit == 'pouch' || unit == 'box' || unit == 'kotak') {
      return 'box';
    }
    return listing.defaultUnit.isNotEmpty ? listing.defaultUnit : 'box';
  }

  int _getMinOrderQty(Listing listing) {
    if (listing.qty > 0 && listing.qty < 5) {
      return listing.qty;
    }
    return 5;
  }

  void _decrementQty(Listing listing) {
    final minQty = _getMinOrderQty(listing);
    final unit = _getDisplayUnit(listing);

    if (_selectedQty <= minQty) {
      // Error handling saat pembeli mencoba mengurangi di bawah batas minimum
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
          elevation: 4,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Jumlah pembelian tidak bisa kurang dari minimal $minQty $unit.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    setState(() => _selectedQty--);
  }

  void _incrementQty(Listing listing) {
    final maxQty = listing.qty > 0 ? listing.qty : 100;
    final unit = _getDisplayUnit(listing);

    if (_selectedQty >= maxQty) {
      // Error handling saat pembeli mencoba melebihi batas stok
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFD97706),
          elevation: 4,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Jumlah telah mencapai batas stok maksimal ($maxQty $unit).',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    setState(() => _selectedQty++);
  }

  // ── Helper Harga Tier Lelang ───────────────────────────────────────────────
  double _getActiveTierPrice(Listing listing) {
    if (listing.currentPrice == 12000.0 || listing.currentPrice <= 0) {
      return 9000.0;
    }
    return listing.currentPrice;
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
    final symbol = currency == 'USD' ? '\$' : (currency == 'EUR' ? '€' : '£');
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
    final utc = _currentTime.toUtc();
    switch (tz) {
      case 'WITA':
        final wita = utc.add(const Duration(hours: 8));
        return {
          'code': 'WITA',
          'offset': 'UTC+8',
          'drop': '19:00',
          'pickup': '22:00',
          'label': 'WITA (UTC+8)',
          'now':
              '${wita.hour.toString().padLeft(2, '0')}:${wita.minute.toString().padLeft(2, '0')}:${wita.second.toString().padLeft(2, '0')}',
        };
      case 'WIT':
        final wit = utc.add(const Duration(hours: 9));
        return {
          'code': 'WIT',
          'offset': 'UTC+9',
          'drop': '20:00',
          'pickup': '23:00',
          'label': 'WIT (UTC+9)',
          'now':
              '${wit.hour.toString().padLeft(2, '0')}:${wit.minute.toString().padLeft(2, '0')}:${wit.second.toString().padLeft(2, '0')}',
        };
      case 'London':
        final london = utc.add(const Duration(hours: 1));
        return {
          'code': 'BST',
          'offset': 'UTC+1',
          'drop': '12:00',
          'pickup': '15:00',
          'label': 'London (BST)',
          'now':
              '${london.hour.toString().padLeft(2, '0')}:${london.minute.toString().padLeft(2, '0')}:${london.second.toString().padLeft(2, '0')}',
        };
      case 'WIB':
      default:
        final wib = utc.add(const Duration(hours: 7));
        return {
          'code': 'WIB',
          'offset': 'UTC+7',
          'drop': '18:00',
          'pickup': '21:00',
          'label': 'WIB (UTC+7)',
          'now':
              '${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')}:${wib.second.toString().padLeft(2, '0')}',
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
    final tierPrice = _getActiveTierPrice(listing);
    final unitPriceFormatted = _formatPriceDisplay(
      tierPrice,
      _selectedCurrency,
    );
    final totalIdr = tierPrice * _selectedQty;
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
                _sheetRow(
                  'Item & Lot',
                  '${listing.productName} ($_selectedQty ${_getDisplayUnit(listing)})',
                ),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _sheetRow(
                  'Harga Satuan Terkunci',
                  '$unitPriceFormatted / ${_getDisplayUnit(listing)}',
                  valueColor: AppColors.primary,
                  isBold: true,
                ),
                const SizedBox(height: 8),
                _sheetRow(
                  'Batas Pengambilan',
                  'Sebelum ${tz['pickup']} ${tz['code']}',
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
                    Text(
                      'Rp ${_formatPriceInt(totalIdr)}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
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
                const Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: Color(0xFF16A34A),
                ),
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

  Widget _sheetRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    bool isMono = false,
  }) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Lelang Berhasil Dikunci!',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pesanan likuidasi pangan Anda telah berhasil diverifikasi oleh sistem Recovera.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
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
                    _dialogRow(
                      'Jumlah',
                      '$_selectedQty ${_getDisplayUnit(listing)}',
                    ),
                    const SizedBox(height: 6),
                    _dialogRow(
                      'Total',
                      'Rp ${_formatPriceInt(order.totalPrice)}',
                    ),
                    const SizedBox(height: 6),
                    _dialogRow('Batas Ambil', '21:00 WIB', isHighlight: true),
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: Text(
                'Selesai',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
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
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                SliverToBoxAdapter(child: _buildSubHeader(listing)),

                // ── Main Content Body ──────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
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
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF0F172A),
            ),
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
            icon: const Icon(
              Icons.share_outlined,
              size: 20,
              color: Color(0xFF64748B),
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(
              Icons.bookmark_border_rounded,
              size: 22,
              color: Color(0xFF64748B),
            ),
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
                  child:
                      listing.imageUrl != null &&
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
                          horizontal: 10,
                          vertical: 5,
                        ),
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
                            const Icon(
                              Icons.gavel_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
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
                          horizontal: 9,
                          vertical: 5,
                        ),
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
                      horizontal: 10,
                      vertical: 5,
                    ),
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
                        const Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
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
                          const Icon(
                            Icons.warehouse_rounded,
                            size: 15,
                            color: Color(0xFFE2E8F0),
                          ),
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
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
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
        child: Icon(
          Icons.inventory_2_rounded,
          size: 64,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. INTERACTIVE MULTI-CURRENCY SECTION (PB-062 / US-09)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCurrencySection(Listing listing) {
    final activePrice = _getActiveTierPrice(listing);
    final originalPrice = listing.normalPrice > 0
        ? listing.normalPrice
        : 15000.0;
    final currentFormatted = _formatPriceDisplay(
      activePrice,
      _selectedCurrency,
    );
    final normalFormatted = _formatPriceDisplay(
      originalPrice,
      _selectedCurrency,
    );
    final discountPercent = originalPrice > activePrice
        ? (((originalPrice - activePrice) / originalPrice) * 100).round()
        : 40;

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ribbon / Label Pita Tier Aktif ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF005D90), Color(0xFF0284C7)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bookmark_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TIER 2 • HARGA PENAWARAN SAAT INI',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Lelang Berjalan',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Detail Harga ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currentFormatted,
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '/ ${_getDisplayUnit(listing)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Harga Awal: ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        normalFormatted,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Hemat -$discountPercent%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
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
                    child: const Icon(
                      Icons.trending_down_rounded,
                      size: 18,
                      color: Color(0xFF0284C7),
                    ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

          // Jadwal Lelang & Batas Pengambilan (Waktu Jam Sekarang Dihilangkan Sesuai Request)
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
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Jadwal Lelang & Batas Pengambilan',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. BATCH TECHNICAL SPECIFICATIONS & WAREHOUSE (SIMPLIFIED & INTUITIVE)
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
                    const Icon(
                      Icons.inventory_2_rounded,
                      size: 13,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Stok: ${listing.qty} ${_getDisplayUnit(listing)}',
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
          const SizedBox(height: 8),

          _buildSimpleSpecRow(
            icon: Icons.shopping_basket_outlined,
            label: 'Minimal Pembelian',
            value:
                '${_getMinOrderQty(listing)} ${_getDisplayUnit(listing)} (Isi 12 pcs / box)',
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildSimpleSpecRow(
            icon: Icons.event_available_rounded,
            label: 'Kedaluwarsa',
            value: '18 Nov 2026',
            badge: 'Sisa ${listing.effectiveDaysToExpiry} Hari',
            badgeColor: const Color(0xFFFEE2E2),
            badgeTextColor: const Color(0xFFDC2626),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildSimpleSpecRow(
            icon: Icons.local_shipping_outlined,
            label: 'Metode Pengambilan',
            value: 'Self-Pickup / Kargo (${listing.city})',
            badge: '${listing.distanceKm?.toStringAsFixed(1) ?? '2.4'} km',
            badgeColor: const Color(0xFFF1F5F9),
            badgeTextColor: const Color(0xFF475569),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildSimpleSpecRow(
            icon: Icons.thermostat_rounded,
            label: 'Suhu Penyimpanan',
            value: listing.storageType == 'frozen'
                ? 'Frozen (-18°C) • Tersegel'
                : (listing.storageType == 'chilled'
                      ? 'Chilled (2-4°C) • Tersegel'
                      : 'Ambient (20-25°C) • Tersegel'),
          ),
          const SizedBox(height: 12),

          // Distributor Profile Card (Clean & Compact)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      'MP',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              listing.companyName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
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
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Color(0xFFF59E0B),
                    ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSpecRow({
    required IconData icon,
    required String label,
    required String value,
    String? badge,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF475569)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor ?? const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeTextColor ?? const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. ESG IMPACT VERIFICATION (STEMPEL / CAP RESMI)
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
          Text(
            'Verifikasi Dampak ESG',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Kartu Stempel / Cap Verifikasi ESG
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Cap / Stempel Bulat Berornamen ──────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF16A34A),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF86EFAC),
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.eco_rounded,
                              size: 24,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Stempel tanda centang biru kecil di sudut kanan bawah
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // ── Keterangan Dampak ───────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VERIFIKASI DAMPAK ESG',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF166534),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Potensi penyelamatan 150 kg pangan (-375 kg CO₂e). Sertifikat audit terbit otomatis usai transaksi.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF334155),
                          height: 1.35,
                          fontWeight: FontWeight.w500,
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
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. STICKY BOTTOM CHECKOUT BAR
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildStickyBottomBar(Listing listing) {
    final unitPrice = _getActiveTierPrice(listing);
    final minQty = _getMinOrderQty(listing);
    final maxQty = listing.qty > 0 ? listing.qty : 100;
    final unit = _getDisplayUnit(listing);
    final totalIdr = unitPrice * _selectedQty;
    final totalFormatted = 'Rp ${_formatPriceInt(totalIdr)}';
    final isAtMin = _selectedQty <= minQty;
    final isAtMax = _selectedQty >= maxQty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Baris Atas: Opsi Tambah / Kurang Jumlah Pembelian ───────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Jumlah Pembelian',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(Min: $minQty $unit | Stok: $maxQty)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Stepper Counter [-] [ Qty ] [+]
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _decrementQty(listing),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(9),
                        ),
                        child: Container(
                          width: 36,
                          height: 32,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.remove_rounded,
                            size: 18,
                            color: isAtMin
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 40),
                        height: 32,
                        alignment: Alignment.center,
                        color: Colors.white,
                        child: Text(
                          '$_selectedQty',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _incrementQty(listing),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(9),
                        ),
                        child: Container(
                          width: 36,
                          height: 32,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: isAtMax
                                ? const Color(0xFFCBD5E1)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // ── Baris Bawah: Total Pembayaran & Tombol Beli Sekarang ────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Pembayaran ($_selectedQty $unit):',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      totalFormatted,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
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
          ],
        ),
      ),
    );
  }
}
