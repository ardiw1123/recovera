import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/listing_repository.dart';
import '../../../data/services/listing_api_service.dart';
import '../models/product_model.dart';
import '../widgets/product_card.dart';
import '../../auth/screens/location_management_screen.dart';

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
  });

  final ListingRepository? repository;
  final double userLat;
  final double userLng;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ListingRepository _listingRepository;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Listing> _allListings = [];
  bool _isLoading = false;
  bool _isFromCache = false;
  String? _errorMessage;

  FoodCategory? _selectedCategory;
  String _selectedSort = 'nearest'; // 'nearest', 'cheapest', 'highest_match'

  double get _effectiveLat =>
      AuthRepository.instance.currentUserProfile?.baseLat ?? widget.userLat;
  double get _effectiveLng =>
      AuthRepository.instance.currentUserProfile?.baseLng ?? widget.userLng;

  @override
  void initState() {
    super.initState();
    AuthRepository.instance.addListener(_onAuthProfileChanged);
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
  void dispose() {
    AuthRepository.instance.removeListener(_onAuthProfileChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Mengambil daftar listing terdekat dari backend REST API via FastAPI.
  /// Bila gagal atau offline, ListingRepository otomatis fallback ke SQLite cache.
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
        category: _selectedCategory?.label,
        search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
      );

      if (mounted) {
        setState(() {
          _isFromCache = result.isFromCache;
          _allListings = result.listings
              .map((m) => Listing.fromCachedModel(m))
              .toList();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allListings = ListingRepository.getDemoListings(
            category: _selectedCategory?.label,
            search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
          ).map((m) => Listing.fromCachedModel(m)).toList();
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
    var items = List<Listing>.from(_allListings);

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

    if (_selectedCategory != null) {
      items = items
          .where((item) => item.category == _selectedCategory)
          .toList();
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
      body: SafeArea(
        child: RefreshIndicator(
          key: const Key('home_refresh_indicator'),
          onRefresh: () => _fetchListings(forceRefresh: true),
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header & Branding ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              // ── Location Pin Bar ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildLocationBar(),
              ),

              // ── Offline Cache Banner Indicator ────────────────────────────
              if (_isFromCache)
                SliverToBoxAdapter(
                  child: _buildOfflineCacheBanner(),
                ),

              // ── Search & Filter Bar ───────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildSearchBar(),
              ),

              // ── Category Filter Chips ─────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildCategoryChips(),
              ),

              // ── Proximity Recommendation Header ───────────────────────────
              SliverToBoxAdapter(
                child: _buildRecommendationHeader(listings.length),
              ),

              // ── Content Area: Loading / Error / Empty / Feed ──────────────
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
    );
  }

  // ── Header Section with Branding & Greeting ───────────────────────────────
  Widget _buildHeader() {
    final buyerGreeting = _getBuyerGreeting();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'RECOVERA B2B',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 10, color: Color(0xFF10B981)),
                          const SizedBox(width: 2),
                          Text(
                            'Verified',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Halo, $buyerGreeting',
                  key: const Key('buyer_greeting_title'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Temukan likuidasi stok pangan terdekat dengan harga terbaik.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF475569),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ── Location Pin Bar ───────────────────────────────────────────────────────
  Widget _buildLocationBar() {
    final locationText = _getBuyerLocationText();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF0284C7),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lokasi Pengiriman Anda',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      locationText,
                      key: const Key('buyer_location_text'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radar_rounded, size: 11, color: Color(0xFF0284C7)),
                    const SizedBox(width: 4),
                    Text(
                      'Radius < 15 km',
                      key: const Key('proximity_radius_badge'),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0369A1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
                borderRadius: BorderRadius.circular(12),
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
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _fetchListings(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: PopupMenuButton<String>(
              key: const Key('btn_home_sort_menu'),
              icon: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
              tooltip: 'Urutkan',
              onSelected: (val) {
                setState(() => _selectedSort = val);
                _fetchListings();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'nearest',
                  child: Text('Terdekat (Proximity)'),
                ),
                const PopupMenuItem(
                  value: 'highest_match',
                  child: Text('Skor Kecocokan Tertinggi'),
                ),
                const PopupMenuItem(
                  value: 'cheapest',
                  child: Text('Harga Termurah'),
                ),
              ],
            ),
          ),
        ],
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
            isSelected: _selectedCategory == null,
            onTap: () {
              setState(() => _selectedCategory = null);
              _fetchListings();
            },
          ),
          ...FoodCategory.values.map(
            (cat) => _buildChip(
              label: cat.label,
              icon: cat.icon,
              isSelected: _selectedCategory == cat,
              onTap: () {
                setState(() => _selectedCategory = cat);
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
                  _selectedCategory = null;
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
