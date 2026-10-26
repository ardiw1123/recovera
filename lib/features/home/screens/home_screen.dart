import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../core/sensors/shake_detector.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/network_connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/app_prefs_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/listing_repository.dart';
import '../../../data/services/listing_api_service.dart';
import '../models/product_model.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/product_card.dart';
import '../../auth/screens/location_management_screen.dart';
import '../../transactions/screens/buyer_transaction_screen.dart';
import '../../chat/screens/chatbot_screen.dart';

/// Dashboard utama bagi pengguna Buyer (Pembeli).
///
/// Menyajikan rekomendasi produk lelang terdekat berdasarkan kedekatan lokasi pembeli & penjual,
/// pencarian, filter kategori, penanganan status offline cache SQLite, dan role guardrails.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.repository,
    this.userLat = -6.2088,
    this.userLng = 106.8456,
    this.sensorStream,
    this.initialRadiusKm = 15.0,
  });

  final ListingRepository? repository;
  final double userLat;
  final double userLng;
  final Stream<AccelerometerEvent>? sensorStream;
  final double initialRadiusKm;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ListingRepository _listingRepository;
  late final ShakeDetector _shakeDetector;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Listing> _allListings = List<Listing>.from(dummyListings);
  bool _isLoading = false;
  bool _isFromCache = false;
  String? _errorMessage;

  Set<FoodCategory>? _selectedCategoriesInternal;
  Set<FoodCategory> get _selectedCategories {
    _selectedCategoriesInternal ??= <FoodCategory>{};
    return _selectedCategoriesInternal!;
  }

  double? _selectedRadiusKm = 15.0; // Default radius 15 km per specifications
  int? _selectedMaxExpiryDays; // null = Semua, 14 = <= 14 hari, 30, 60
  String _selectedSort = 'nearest'; // 'nearest', 'cheapest', 'expiring_soon', 'highest_match'

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategories.isNotEmpty) count += _selectedCategories.length;
    if (_selectedRadiusKm != null && _selectedRadiusKm != 15.0) count++;
    if (_selectedMaxExpiryDays != null) count++;
    if (_selectedSort != 'nearest') count++;
    return count;
  }

  bool get _hasActiveFilters =>
      _selectedCategories.isNotEmpty ||
      (_selectedRadiusKm != null && _selectedRadiusKm != 15.0) ||
      _selectedMaxExpiryDays != null ||
      _selectedSort != 'nearest';

  String _getSortLabel(String code) {
    switch (code) {
      case 'cheapest':
        return 'Harga Termurah';
      case 'expiring_soon':
      case 'expiring':
      case 'expiry':
        return 'Segera Kedaluwarsa';
      case 'highest_match':
      case 'discount':
        return 'Diskon Tertinggi';
      case 'nearest':
      default:
        return 'Terdekat';
    }
  }

  double get _effectiveLat =>
      AuthRepository.instance.currentUserProfile?.baseLat ?? widget.userLat;
  double get _effectiveLng =>
      AuthRepository.instance.currentUserProfile?.baseLng ?? widget.userLng;

  @override
  void initState() {
    super.initState();
    _selectedRadiusKm = widget.initialRadiusKm;
    WidgetsBinding.instance.addObserver(this);
    _shakeDetector = ShakeDetector(
      onShake: _onShakeToRefresh,
      sensorStream: widget.sensorStream,
    );
    _shakeDetector.startListening();
    _allListings = List<Listing>.from(dummyListings);
    AuthRepository.instance.addListener(_onAuthProfileChanged);
    NetworkConnectivityService.instance.addListener(_onConnectivityChanged);
    final client = ApiClient();
    _listingRepository = widget.repository ??
        ListingRepository(remoteClient: ListingApiService(client: client));
    _fetchListings();
  }

  void _onAuthProfileChanged() {
    if (mounted) {
      setState(() {});
      _fetchListings(forceRefresh: false);
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userLat != widget.userLat || oldWidget.userLng != widget.userLng) {
      _fetchListings();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _shakeDetector.startListening();
    } else {
      _shakeDetector.stopListening();
    }
  }

  void _onShakeToRefresh() {
    if (!mounted || _isLoading) return;

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Memperbarui daftar lelang...'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    _fetchListings(forceRefresh: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shakeDetector.dispose();
    AuthRepository.instance.removeListener(_onAuthProfileChanged);
    NetworkConnectivityService.instance.removeListener(_onConnectivityChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (!mounted) return;
    final isOnline = NetworkConnectivityService.instance.isOnline;
    if (isOnline) {
      _fetchListings(forceRefresh: true);
      _listingRepository.syncPendingDrafts().catchError(
            (_) => const DraftSyncResult(totalCount: 0, syncedCount: 0, failedCount: 0, errors: []),
          );
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terhubung ke Internet: Memuat layanan lelang live...'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _fetchListings(forceRefresh: false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mode Offline: Menampilkan data cache SQLite lokal.'),
          backgroundColor: AppColors.secondary,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Mengambil daftar listing terdekat dari backend REST API via FastAPI.
  /// Bila gagal atau offline, ListingRepository otomatis fallback ke SQLite cache / dummyListings.
  Future<void> _fetchListings({bool forceRefresh = true}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _listingRepository.getListings(
        forceRefresh: forceRefresh,
        lat: _effectiveLat,
        lng: _effectiveLng,
        sort: _selectedSort,
        category: _selectedCategories.length == 1
            ? _selectedCategories.first.label
            : null,
        radiusKm: _selectedRadiusKm,
        minDays: _selectedMaxExpiryDays != null ? 1 : null,
        search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
      );

      if (mounted) {
        setState(() {
          _isFromCache = result.isFromCache;
          if (result.listings.isNotEmpty) {
            _allListings = result.listings
                .map((m) => Listing.fromCachedModel(m))
                .toList();
          } else {
            // Fallback ke dummyListings jika remote / cache kosong agar katalog stok selalu tampil
            _allListings = List<Listing>.from(dummyListings);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final demo = ListingRepository.getDemoListings(
            category: _selectedCategories.length == 1
                ? _selectedCategories.first.label
                : null,
            search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
            radiusKm: _selectedRadiusKm,
            minDays: _selectedMaxExpiryDays,
            sort: _selectedSort,
          ).map((m) => Listing.fromCachedModel(m)).toList();
          _allListings = demo.isNotEmpty ? demo : List<Listing>.from(dummyListings);
          _isFromCache = true;
          _errorMessage = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Filter data di memori bila pencarian lokal dilakukan
  List<Listing> get _filteredListings {
    var items = _allListings.isNotEmpty
        ? List<Listing>.from(_allListings)
        : List<Listing>.from(dummyListings);

    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items
          .where((item) =>
              item.productName.toLowerCase().contains(query) ||
              item.companyName.toLowerCase().contains(query) ||
              (item.brand?.toLowerCase().contains(query) ?? false) ||
              item.city.toLowerCase().contains(query))
          .toList();
    }

    if (_selectedCategories.isNotEmpty) {
      items = items
          .where((item) => _selectedCategories.contains(item.category))
          .toList();
    }

    // Invariant: Produk yang sudah melewati tanggal kedaluwarsa (<= 0) tidak ditampilkan di etalase pembeli
    items = items.where((item) => item.effectiveDaysToExpiry > 0).toList();

    if (_selectedMaxExpiryDays != null) {
      items = items
          .where((item) =>
              item.effectiveDaysToExpiry > 0 &&
              item.effectiveDaysToExpiry <= _selectedMaxExpiryDays!)
          .toList();
    }

    if (_selectedRadiusKm != null && _selectedRadiusKm != 15.0) {
      items = items
          .where((item) => item.distanceKm == null || item.distanceKm! <= _selectedRadiusKm!)
          .toList();
    }

    switch (_selectedSort) {
      case 'cheapest':
        items.sort((a, b) => a.startPrice.compareTo(b.startPrice));
        break;
      case 'expiring_soon':
      case 'expiring':
      case 'expiry':
        items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
        break;
      case 'highest_match':
      case 'discount':
        items.sort((a, b) => b.effectiveDiscountPercent.compareTo(a.effectiveDiscountPercent));
        break;
      case 'nearest':
      default:
        items.sort((a, b) {
          final da = a.distanceKm ?? 999999.0;
          final db = b.distanceKm ?? 999999.0;
          return da.compareTo(db);
        });
        break;
    }

    return items;
  }

  String _getBuyerGreeting() {
    final profile = AuthRepository.instance.currentUserProfile;
    final tokens = AuthRepository.instance.currentTokens;

    if (profile?.companyName != null && profile!.companyName!.isNotEmpty) {
      return profile.companyName!;
    }
    if (profile?.name != null && profile!.name.isNotEmpty) {
      return profile.name;
    }
    final role = tokens?.role;
    if (role != null && role.isNotEmpty) {
      return role == 'buyer' ? 'Mitra Bisnis' : role;
    }
    return 'Mitra Bisnis';
  }

  String _getBuyerLocationText() {
    final profile = AuthRepository.instance.currentUserProfile;
    final address = profile?.address?.trim();
    if (address != null && address.isNotEmpty) {
      return address;
    }
    final city = profile?.city?.trim();
    if (city != null && city.isNotEmpty) {
      return '$city, Indonesia';
    }
    return 'Jakarta Pusat, Indonesia';
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
        key: const Key('fab_chatbot_buyer'),
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
        child: const Icon(
          Icons.smart_toy_rounded,
          color: AppColors.white,
          size: 26,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Role Guard: Seller restriction ───────────────────────────────────────
    if (AuthRepository.instance.isSeller) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            'Beranda Pembeli',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gpp_bad_rounded,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Akses Terbatas: Khusus Pembeli',
                  key: const Key('seller_access_restricted_title'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Akun penjual tidak diizinkan mengakses fitur discovery katalog pembeli.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.slateText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final listings = _filteredListings;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _buildChatbotFab(),
      body: Column(
        children: [
          // ── Fixed Wave Header (Sticky, tidak ikut ter-scroll) ───────────
          _buildFixedWaveHeader(),

          // ── Offline Cache Banner Indicator ──────────────────────────────
          if (_isFromCache) _buildOfflineCacheBanner(),

          // ── Scrollable Body Catalog ─────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              key: const Key('home_refresh_indicator'),
              onRefresh: () => _fetchListings(forceRefresh: true),
              color: AppColors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Search & Filter Bar ─────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildSearchBar(),
                  ),

                  // ── Category Filter Chips ───────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildCategoryChips(),
                  ),

                  // ── Active Filters Bar ──────────────────────────────────
                  if (_hasActiveFilters)
                    SliverToBoxAdapter(
                      child: _buildActiveFiltersBar(),
                    ),

                  // ── Proximity Recommendation Header ─────────────────────
                  SliverToBoxAdapter(
                    child: _buildRecommendationHeader(listings.length),
                  ),

                  // ── Content Area: Loading / Error / Empty / Feed ────────
                  if (_isLoading && _allListings.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildLoadingSkeleton(),
                    )
                  else if (_errorMessage != null && _allListings.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildErrorState(),
                    )
                  else if (listings.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = listings[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ProductCard(listing: item),
                            );
                          },
                          childCount: listings.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 32),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Fixed Wave Header with Recovera Brand, Greeting, Location & Notification ───
  Widget _buildFixedWaveHeader() {
    final buyerGreeting = _getBuyerGreeting();
    final locationText = _getBuyerLocationText();

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
                    // Sisi Kiri: Logo Brand Recovera, Greeting Pembeli, dan Lokasi
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Logo Recovera & Teks Brand ──
                          Row(
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
                            ],
                          ),
                          const SizedBox(height: 6),

                          // ── Greeting Pembeli: "Halo, [nama/Govina]!" ──
                          Text(
                            'Halo, $buyerGreeting',
                            key: const Key('buyer_greeting_title'),
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

                          // ── Bar Lokasi Pengiriman (Dialihkan ke pemilihan lokasi saat diklik) ──
                          GestureDetector(
                            key: const Key('home_location_bar_button'),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LocationManagementScreen(),
                                ),
                              );
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: Color(0xFF90E0EF),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      locationText,
                                      key: const Key('buyer_location_text'),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    key: const Key('btn_proximity_filter'),
                                    onTap: () => _showFilterBottomSheet(context),
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.radar_rounded, size: 10, color: Color(0xFF90E0EF)),
                                          const SizedBox(width: 3),
                                          Text(
                                            _selectedRadiusKm == 15.0
                                                ? 'Radius < 15 km'
                                                : (_selectedRadiusKm != null
                                                    ? 'Radius < ${_selectedRadiusKm!.toInt()} km'
                                                    : 'Semua Radius'),
                                            key: const Key('proximity_radius_badge'),
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  ListenableBuilder(
                                    listenable: AppPrefsRepository.instance,
                                    builder: (context, _) {
                                      final cur = AppPrefsRepository.instance.selectedCurrency;
                                      final tz = AppPrefsRepository.instance.selectedTimezone;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.22),
                                          borderRadius: BorderRadius.circular(10),
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

                    // ── Tombol Riwayat Transaksi (Kanan Atas) ──
                    GestureDetector(
                      key: const Key('btn_home_transactions'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BuyerTransactionScreen(),
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
                      key: const Key('btn_home_notification'),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Belum ada notifikasi baru untuk Anda.',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            Positioned(
                              top: 9,
                              right: 10,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                ),
                              ),
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
        ),
      ],
    );
  }

  // ── Offline Mode Banner Indicator ──────────────────────────────────────────
  Widget _buildOfflineCacheBanner() {
    return Container(
      key: const Key('offline_indicator_banner'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode Offline — Menampilkan data cache SQLite',
              key: const Key('offline_indicator_text'),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search & Filter Bar ───────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                key: const Key('home_search_field'),
                controller: _searchCtrl,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Cari produk pangan, distributor, kota...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF64748B),
                    size: 18,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _fetchListings(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: const Key('btn_home_filter'),
            onTap: () => _showFilterBottomSheet(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _activeFilterCount > 0 ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _activeFilterCount > 0 ? AppColors.primary : const Color(0xFFCBD5E1),
                ),
                boxShadow: _activeFilterCount > 0
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    key: const Key('btn_home_sort_menu'),
                    color: _activeFilterCount > 0 ? Colors.white : AppColors.primary,
                    size: 19,
                  ),
                  if (_activeFilterCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_activeFilterCount',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Active Filters Bar ────────────────────────────────────────────────────
  Widget _buildActiveFiltersBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._selectedCategories.map(
              (cat) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _buildActiveFilterPill(
                  label: cat.label,
                  icon: cat.icon,
                  onRemove: () {
                    setState(() => _selectedCategories.remove(cat));
                    _fetchListings();
                  },
                ),
              ),
            ),
            if (_selectedRadiusKm != null && _selectedRadiusKm != 15.0) ...[
              _buildActiveFilterPill(
                key: const Key('chip_active_radius'),
                closeKey: const Key('btn_clear_radius_filter'),
                label: 'Jarak: ${_selectedRadiusKm!.toInt()} km',
                icon: Icons.radar_rounded,
                onRemove: () {
                  setState(() => _selectedRadiusKm = 15.0);
                  _fetchListings();
                },
              ),
              const SizedBox(width: 6),
            ],
            if (_selectedMaxExpiryDays != null) ...[
              _buildActiveFilterPill(
                label: 'Exp ≤ $_selectedMaxExpiryDays Hari',
                icon: Icons.hourglass_bottom_rounded,
                onRemove: () {
                  setState(() => _selectedMaxExpiryDays = null);
                  _fetchListings();
                },
              ),
              const SizedBox(width: 6),
            ],
            if (_selectedSort != 'nearest') ...[
              _buildActiveFilterPill(
                label: _getSortLabel(_selectedSort),
                icon: Icons.swap_vert_rounded,
                onRemove: () {
                  setState(() => _selectedSort = 'nearest');
                  _fetchListings();
                },
              ),
              const SizedBox(width: 6),
            ],
            GestureDetector(
              key: const Key('btn_clear_all_active_filters'),
              onTap: () {
                setState(() {
                  _selectedCategories.clear();
                  _selectedRadiusKm = 15.0;
                  _selectedMaxExpiryDays = null;
                  _selectedSort = 'nearest';
                });
                _fetchListings();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Reset Semua',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterPill({
    Key? key,
    Key? closeKey,
    required String label,
    required IconData icon,
    required VoidCallback onRemove,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            key: closeKey,
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: const Icon(
              Icons.close_rounded,
              size: 13,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter Bottom Sheet (PBI-09) ──────────────────────────────────────────
  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(
        selectedCategories: _selectedCategories,
        selectedExpiryPreset: _selectedMaxExpiryDays != null
            ? (_selectedMaxExpiryDays! <= 7
                ? '1-7'
                : (_selectedMaxExpiryDays! <= 14
                    ? '8-14'
                    : '15-30'))
            : 'all',
        selectedSort: _selectedSort,
        selectedRadiusKm: _selectedRadiusKm ?? 15.0,
        onApply: (cats, expiry, sort, radius) {
          setState(() {
            _selectedCategories.clear();
            _selectedCategories.addAll(cats);
            _selectedSort = sort;
            _selectedRadiusKm = radius;
            if (expiry == '1-7') {
              _selectedMaxExpiryDays = 7;
            } else if (expiry == '8-14') {
              _selectedMaxExpiryDays = 14;
            } else if (expiry == '15-30') {
              _selectedMaxExpiryDays = 30;
            } else {
              _selectedMaxExpiryDays = null;
            }
          });
          _fetchListings();
        },
      ),
    );
    return;
    // ignore: dead_code
    final Set<FoodCategory> tempCategories =
        Set<FoodCategory>.from(_selectedCategories);
    double? tempRadiusKm = _selectedRadiusKm;
    int? tempMaxExpiryDays = _selectedMaxExpiryDays;
    String tempSort = _selectedSort;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Sheet Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filter & Urutkan Katalog',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Saring bahan baku berdasarkan jarak, waktu & kategori',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            key: const Key('btn_sheet_reset_filters'),
                            onPressed: () {
                              setModalState(() {
                                tempCategories.clear();
                                tempRadiusKm = 15.0;
                                tempMaxExpiryDays = null;
                                tempSort = 'nearest';
                              });
                            },
                            child: Text(
                              'Reset',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Scrollable Filter Sections
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Section 1: Kategori Produk ─────────────────────
                            _buildFilterSectionTitle('Kategori Bahan Baku (Bisa Pilih Beberapa)', Icons.category_outlined),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildSheetChoiceChip(
                                  label: 'Semua Kategori',
                                  isSelected: tempCategories.isEmpty,
                                  onTap: () => setModalState(() => tempCategories.clear()),
                                ),
                                ...FoodCategory.values.map(
                                  (cat) => _buildSheetChoiceChip(
                                    label: cat.label,
                                    icon: cat.icon,
                                    isSelected: tempCategories.contains(cat),
                                    onTap: () => setModalState(() {
                                      if (tempCategories.contains(cat)) {
                                        tempCategories.remove(cat);
                                      } else {
                                        tempCategories.add(cat);
                                      }
                                    }),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // ── Section 2: Radius Gudang Penjual (LBS) ─────────
                            _buildFilterSectionTitle('Radius Jarak Gudang (LBS)', Icons.radar_rounded),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildSheetChoiceChip(
                                  label: 'Semua Jarak',
                                  isSelected: tempRadiusKm == null,
                                  onTap: () => setModalState(() => tempRadiusKm = null),
                                ),
                                _buildSheetChoiceChip(
                                  label: '≤ 5 km (Sangat Dekat)',
                                  isSelected: tempRadiusKm == 5.0,
                                  onTap: () => setModalState(() => tempRadiusKm = 5.0),
                                ),
                                _buildSheetChoiceChip(
                                  label: '< 15 km (Standar)',
                                  isSelected: tempRadiusKm == 15.0,
                                  onTap: () => setModalState(() => tempRadiusKm = 15.0),
                                ),
                                _buildSheetChoiceChip(
                                  label: '≤ 30 km',
                                  isSelected: tempRadiusKm == 30.0,
                                  onTap: () => setModalState(() => tempRadiusKm = 30.0),
                                ),
                                _buildSheetChoiceChip(
                                  label: '≤ 50 km',
                                  isSelected: tempRadiusKm == 50.0,
                                  onTap: () => setModalState(() => tempRadiusKm = 50.0),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // ── Section 3: Sisa Hari Kedaluwarsa ───────────────
                            _buildFilterSectionTitle('Sisa Umur Simpan (Kedaluwarsa)', Icons.hourglass_bottom_rounded),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildSheetChoiceChip(
                                  label: 'Semua Waktu',
                                  isSelected: tempMaxExpiryDays == null,
                                  onTap: () => setModalState(() => tempMaxExpiryDays = null),
                                ),
                                _buildSheetChoiceChip(
                                  label: '≤ 14 Hari (Prioritas/Mendesak)',
                                  icon: Icons.warning_amber_rounded,
                                  activeColor: const Color(0xFFD97706),
                                  isSelected: tempMaxExpiryDays == 14,
                                  onTap: () => setModalState(() => tempMaxExpiryDays = 14),
                                ),
                                _buildSheetChoiceChip(
                                  label: '≤ 30 Hari (Bulan Ini)',
                                  isSelected: tempMaxExpiryDays == 30,
                                  onTap: () => setModalState(() => tempMaxExpiryDays = 30),
                                ),
                                _buildSheetChoiceChip(
                                  label: '≤ 60 Hari',
                                  isSelected: tempMaxExpiryDays == 60,
                                  onTap: () => setModalState(() => tempMaxExpiryDays = 60),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // ── Section 4: Urutan (Sort) ───────────────────────
                            _buildFilterSectionTitle('Urutkan Hasil', Icons.swap_vert_rounded),
                            const SizedBox(height: 10),
                            Column(
                              children: [
                                _buildSortOptionTile(
                                  title: 'Terdekat (Proximity)',
                                  subtitle: 'Prioritaskan gudang seller terdekat dari lokasi Anda',
                                  icon: Icons.near_me_rounded,
                                  isSelected: tempSort == 'nearest',
                                  onTap: () => setModalState(() => tempSort = 'nearest'),
                                ),
                                const SizedBox(height: 8),
                                _buildSortOptionTile(
                                  title: 'Harga Termurah',
                                  subtitle: 'Urutkan dari harga penawaran saat ini terendah',
                                  icon: Icons.payments_outlined,
                                  isSelected: tempSort == 'cheapest',
                                  onTap: () => setModalState(() => tempSort = 'cheapest'),
                                ),
                                const SizedBox(height: 8),
                                _buildSortOptionTile(
                                  title: 'Segera Kedaluwarsa',
                                  subtitle: 'Bahan baku yang paling cepat mencapai batas kedaluwarsa',
                                  icon: Icons.timer_outlined,
                                  isSelected: tempSort == 'expiring_soon' || tempSort == 'expiring',
                                  onTap: () => setModalState(() => tempSort = 'expiring_soon'),
                                ),
                                const SizedBox(height: 8),
                                _buildSortOptionTile(
                                  title: 'Diskon & Kecocokan Tertinggi',
                                  subtitle: 'Potongan harga terbesar dari harga normal seller',
                                  icon: Icons.percent_rounded,
                                  isSelected: tempSort == 'highest_match',
                                  onTap: () => setModalState(() => tempSort = 'highest_match'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Action
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          key: const Key('btn_apply_filter_sheet'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedCategories
                                ..clear()
                                ..addAll(tempCategories);
                              _selectedRadiusKm = tempRadiusKm;
                              _selectedMaxExpiryDays = tempMaxExpiryDays;
                              _selectedSort = tempSort;
                            });
                            _fetchListings();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Terapkan Filter',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
          },
        );
      },
    );
  }

  Widget _buildFilterSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildSheetChoiceChip({
    required String label,
    IconData? icon,
    Color? activeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final effectiveColor = activeColor ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? effectiveColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? effectiveColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? effectiveColor : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? effectiveColor : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFDCFCE7) : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF15803D) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? const Color(0xFF15803D) : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: Color(0xFF16A34A),
              ),
          ],
        ),
      ),
    );
  }

  // ── Category Filter Chips ─────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "Semua" Chip
          _buildChip(
            label: 'Semua',
            isSelected: _selectedCategories.isEmpty,
            onTap: () {
              setState(() => _selectedCategories.clear());
              _fetchListings();
            },
          ),
          ...FoodCategory.values.map(
            (cat) => _buildChip(
              label: cat.label,
              icon: cat.icon,
              isSelected: _selectedCategories.contains(cat),
              onTap: () {
                setState(() {
                  if (_selectedCategories.contains(cat)) {
                    _selectedCategories.remove(cat);
                  } else {
                    _selectedCategories.add(cat);
                  }
                });
                _fetchListings();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        labelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  // ── Recommendation Section Header ─────────────────────────────────────────
  Widget _buildRecommendationHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.radar_rounded,
                size: 18,
                color: Color(0xFF059669),
              ),
              const SizedBox(width: 6),
              Text(
                'Rekomendasi Terdekat',
                key: const Key('section_recommendations_title'),
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
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Text(
              '$count Produk',
              key: const Key('recommendation_count_badge'),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF047857),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading Skeleton State ────────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return Padding(
      key: const Key('home_loading_skeleton'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 88,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 80, height: 10, color: const Color(0xFFF1F5F9)),
                        const SizedBox(height: 8),
                        Container(width: 140, height: 14, color: const Color(0xFFF1F5F9)),
                        const SizedBox(height: 8),
                        Container(width: 100, height: 12, color: const Color(0xFFF1F5F9)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      key: const Key('home_empty_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada stok lelang di dekat lokasi Anda',
              key: const Key('empty_state_title'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coba ubah kata kunci pencarian atau bersihkan filter kategori untuk menemukan produk lainnya.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('btn_reset_filters'),
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _selectedCategories.clear();
                  _selectedRadiusKm = 15.0;
                  _selectedMaxExpiryDays = null;
                  _selectedSort = 'nearest';
                });
                _fetchListings();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Reset Filter',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      key: const Key('home_error_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal Memuat Rekomendasi Terdekat',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Terjadi kendala jaringan saat menghubungi server Recovera.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('btn_home_retry'),
              onPressed: () => _fetchListings(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Coba Lagi',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Clipper untuk gelombang header bawah (sesuai coretan sketsa pengguna)
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 24);
    // Gelombang dari kiri ke kanan (melengkung turun lalu naik sedikit)
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
