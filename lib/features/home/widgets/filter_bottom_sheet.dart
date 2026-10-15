import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/product_model.dart';

/// PBI-09 Layar 02 — Bottom Sheet Filter & Urutkan (3/4 tinggi)
///
/// Menampilkan:
/// 1. Kategori Produk (multi‑select)
/// 2. Sisa Hari Kedaluwarsa (preset chips)
/// 3. Urutkan Berdasarkan (radio)
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({
    super.key,
    required this.selectedCategories,
    required this.selectedExpiryPreset,
    required this.selectedSort,
    required this.onApply,
  });

  final Set<FoodCategory> selectedCategories;
  final String selectedExpiryPreset; // '1-7', '8-14', '15-30', 'all'
  final String selectedSort; // 'cheapest', 'expiry', 'discount', 'nearest'
  final void Function(
    Set<FoodCategory> categories,
    String expiryPreset,
    String sort,
  ) onApply;

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Set<FoodCategory> _categories;
  late String _expiryPreset;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _categories = Set.from(widget.selectedCategories);
    _expiryPreset = widget.selectedExpiryPreset;
    _sort = widget.selectedSort;
  }

  void _reset() {
    setState(() {
      _categories.clear();
      _expiryPreset = 'all';
      _sort = 'cheapest';
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Drag handle ─────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),

              // ── Header ──────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filter & Urutkan',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _reset,
                      child: Text(
                        'Reset',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // ── Scrollable body ─────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildCategorySection(),
                    const SizedBox(height: 24),
                    _buildExpirySection(),
                    const SizedBox(height: 24),
                    _buildSortSection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── Sticky CTA ─────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: const Border(
                    top: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.onApply(_categories, _expiryPreset, _sort);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        'Terapkan Filter',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 4,
                        shadowColor:
                            AppColors.primary.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // Section 1: Kategori Produk (Multi‑Select Grid)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1. KATEGORI PRODUK (MULTI‑SELECT)',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                letterSpacing: 0.8,
              ),
            ),
            if (_categories.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_categories.length} Dipilih',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: FoodCategory.values.map((cat) {
            final isSelected = _categories.contains(cat);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _categories.remove(cat);
                  } else {
                    _categories.add(cat);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: (MediaQuery.of(context).size.width - 58) / 2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFFF0F9FF) : AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        cat.icon,
                        size: 14,
                        color: isSelected ? AppColors.white : cat.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 18,
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFFCBD5E1),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section 2: Sisa Hari Kedaluwarsa (Preset Chips)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildExpirySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: const Color(0xFFF1F5F9)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '2. SISA HARI KEDALUWARSA',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                letterSpacing: 0.8,
              ),
            ),
            if (_expiryPreset != 'all')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _expiryLabel(_expiryPreset),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tampilkan bahan pangan yang membutuhkan penyerapan cepat',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),

        // Visual slider representation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      Expanded(
                        flex: _expiryPreset == '1-7' ? 3 : 1,
                        child: Container(
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Container(
                          color: AppColors.primary,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Container(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '1 Hari (Urgent)',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    '14 Hari',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '30 Hari',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Quick preset chips
        Row(
          children: [
            _expiryChip('1-7', '1–7 Hari'),
            const SizedBox(width: 8),
            _expiryChip('8-14', '8–14 Hari'),
            const SizedBox(width: 8),
            _expiryChip('15-30', '15–30 Hari'),
          ],
        ),
      ],
    );
  }

  Widget _expiryChip(String value, String label) {
    final isSelected = _expiryPreset == value;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            setState(() => _expiryPreset = isSelected ? 'all' : value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0F9FF) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            isSelected ? '$label ✓' : label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : const Color(0xFF334155),
            ),
          ),
        ),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // Section 3: Urutkan Berdasarkan (Radio)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSortSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: const Color(0xFFF1F5F9)),
        const SizedBox(height: 16),
        Text(
          '3. URUTKAN BERDASARKAN',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        _sortOption(
          value: 'cheapest',
          icon: Icons.swap_vert_rounded,
          iconBg: AppColors.primary.withValues(alpha: 0.1),
          iconColor: AppColors.primary,
          title: 'Harga Termurah',
          subtitle: 'Prioritas margin terbaik untuk UMKM',
        ),
        const SizedBox(height: 8),
        _sortOption(
          value: 'expiry',
          icon: Icons.timer_outlined,
          iconBg: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          title: 'Kedaluwarsa Terdekat',
        ),
        const SizedBox(height: 8),
        _sortOption(
          value: 'discount',
          icon: Icons.percent_rounded,
          iconBg: const Color(0xFFFEF2F2),
          iconColor: const Color(0xFFDC2626),
          title: 'Diskon Tertinggi',
        ),
        const SizedBox(height: 8),
        _sortOption(
          value: 'nearest',
          icon: Icons.near_me_rounded,
          iconBg: const Color(0xFFECFDF5),
          iconColor: const Color(0xFF059669),
          title: 'Jarak Gudang Terdekat (<15 km)',
        ),
      ],
    );
  }

  Widget _sortOption({
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
  }) {
    final isSelected = _sort == value;
    return GestureDetector(
      onTap: () => setState(() => _sort = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F9FF) : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFCBD5E1),
                  width: isSelected ? 5 : 1,
                ),
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
