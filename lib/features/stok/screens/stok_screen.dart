import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/models/product_model.dart';
import '../../home/widgets/product_card.dart';
import '../../home/widgets/filter_bottom_sheet.dart';
import '../../home/widgets/empty_state_view.dart';

// Alias agar kode di bawah tetap singkat
typedef _L = Listing;

/// PBI-09 — Layar Stok & Katalog
///
/// Terdiri dari:
///  • Location pin bar
///  • Search bar + Filter button
///  • Horizontal category chips (multi‑select)
///  • Active filter tags ribbon
///  • Result count + sort pill
///  • Product card list / empty state
class StokScreen extends StatefulWidget {
  const StokScreen({super.key});

  @override
  State<StokScreen> createState() => _StokScreenState();
}

class _StokScreenState extends State<StokScreen> {
  // ── State ──────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  Set<FoodCategory> _selectedCategories = {};
  String _expiryPreset = 'all';
  String _sortKey = 'cheapest';

  List<Listing> get _filteredProducts {
    var list = List<Listing>.from(dummyListings);

    // Filter by search query (products.name, products.brand, sellers.company_name)
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where((p) =>
              p.productName.toLowerCase().contains(query) ||
              (p.brand?.toLowerCase().contains(query) ?? false) ||
              p.companyName.toLowerCase().contains(query))
          .toList();
    }

    // Filter by categories
    if (_selectedCategories.isNotEmpty) {
      list =
          list.where((p) => _selectedCategories.contains(p.category)).toList();
    }

    // Filter by expiry preset (listings.expiry_date derived → daysUntilExpiry)
    if (_expiryPreset == '1-7') {
      list = list.where((p) => p.daysUntilExpiry <= 7).toList();
    } else if (_expiryPreset == '8-14') {
      list = list.where((p) => p.daysUntilExpiry <= 14).toList();
    } else if (_expiryPreset == '15-30') {
      list = list.where((p) => p.daysUntilExpiry <= 30).toList();
    }

    // Sort (pakai field DB: start_price, expiry_date, discount_percent)
    switch (_sortKey) {
      case 'cheapest':
        list.sort((a, b) => a.startPrice.compareTo(b.startPrice));
        break;
      case 'expiry':
        list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
        break;
      case 'discount':
        list.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
        break;
      case 'nearest':
        // TODO: hitung jarak dari buyer.base_lat/lng ke sellers.warehouse_lat/lng
        list.sort((a, b) => a.city.compareTo(b.city));
        break;
    }

    return list;
  }

  bool get _hasActiveFilters =>
      _selectedCategories.isNotEmpty || _expiryPreset != 'all';

  void _clearAllFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedCategories = {};
      _expiryPreset = 'all';
      _sortKey = 'cheapest';
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(
        selectedCategories: _selectedCategories,
        selectedExpiryPreset: _expiryPreset,
        selectedSort: _sortKey,
        onApply: (cats, expiry, sort) {
          setState(() {
            _selectedCategories = cats;
            _expiryPreset = expiry;
            _sortKey = sort;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Sticky header ──────────────────────────────────────────
          _buildStickyHeader(),

          // ── Body ───────────────────────────────────────────────────
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: EmptyStateView(
                        onResetFilter: _clearAllFilters,
                        onShowAll: _clearAllFilters,
                      ),
                    ),
                  )
                : _buildProductList(products),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sticky Header
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStickyHeader() {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLocationBar(),
            _buildSearchBar(),
            const SizedBox(height: 4),
            _buildCategoryRow(),
            if (_hasActiveFilters) _buildActiveFilterTags(),
            _buildSubHeader(),
          ],
        ),
      ),
    );
  }

  // ── Location Pin Bar ──────────────────────────────────────────────────

  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Jl. Merpati St, 86L, Depok',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF334155),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
                  'Gudang < 15km',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: 'Cari nama bahan baku atau merek...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() => _searchCtrl.clear()),
                          child: const Icon(
                            Icons.cancel_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openFilterSheet,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: AppColors.white,
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.white,
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check,
                            size: 8,
                            color: AppColors.white,
                          ),
                        ),
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

  // ── Category Horizontal Scroll ────────────────────────────────────────

  Widget _buildCategoryRow() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'KATEGORI PANGAN B2B',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.8,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedCategories.length ==
                          FoodCategory.values.length) {
                        _selectedCategories.clear();
                      } else {
                        _selectedCategories = Set.from(FoodCategory.values);
                      }
                    });
                  },
                  child: Text(
                    _selectedCategories.length == FoodCategory.values.length
                        ? 'Hapus Semua'
                        : 'Pilih Semua',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: FoodCategory.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final cat = FoodCategory.values[i];
                final isSelected = _selectedCategories.contains(cat);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedCategories.remove(cat);
                      } else {
                        _selectedCategories.add(cat);
                      }
                    });
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? null
                              : Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          cat.icon,
                          size: 20,
                          color: isSelected ? AppColors.white : cat.color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Active Filter Tags ────────────────────────────────────────────────

  Widget _buildActiveFilterTags() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFFF0F9FF).withValues(alpha: 0.6),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_alt_rounded,
                  size: 11, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                'Aktif:',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_selectedCategories.isNotEmpty)
                    _filterTag(
                      _selectedCategories.map((c) => c.label).join(', '),
                      () => setState(() => _selectedCategories.clear()),
                    ),
                  if (_expiryPreset != 'all') ...[
                    const SizedBox(width: 6),
                    _filterTag(
                      'Exp: ${_expiryLabel(_expiryPreset)}',
                      () => setState(() => _expiryPreset = 'all'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _clearAllFilters,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Hapus Semua',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTag(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  String _expiryLabel(String preset) {
    switch (preset) {
      case '1-7':
        return '1 - 7 Hari';
      case '8-14':
        return '1 - 14 Hari';
      case '15-30':
        return '15 - 30 Hari';
      default:
        return 'Semua';
    }
  }

  // ── Sub-header (count + sort) ─────────────────────────────────────────

  Widget _buildSubHeader() {
    final count = _filteredProducts.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Menampilkan $count barang',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFFCBD5E1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'B2B Verified',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _openFilterSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '↓↑',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _sortLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _sortLabel {
    switch (_sortKey) {
      case 'cheapest':
        return 'Termurah';
      case 'expiry':
        return 'Exp Terdekat';
      case 'discount':
        return 'Diskon ↑';
      case 'nearest':
        return 'Terdekat';
      default:
        return 'Urutkan';
    }
  }

  // ── Product List ─────────────────────────────────────────────────────

  Widget _buildProductList(List<Listing> listings) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: listings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => ProductCard(listing: listings[i]),
    );
  }
}
