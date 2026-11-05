import '../../../core/network/api_client.dart';
import '../../../data/models/cached_order_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../data/services/order_api_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/network_connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/app_prefs_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../models/seller_inventory_model.dart';
import '../repositories/seller_repository.dart';
import 'seller_product_detail_screen.dart';
import 'upload_stock_flow_screen.dart';

/// Screen Stok Saya (Seller Inventory)
///
/// Mengikuti referensi visual tetap (fixed reference) `seller-inventory-screen.png`:
/// • Header "Stok Saya" + pill counter "X stok aktif" + tombol filter
/// • Search bar "Cari stok..."
/// • Tabs filter: Semua, Aktif, Terjual, Expired
/// • Kartu stok dengan foto produk, nama produk, quantity & unit, harga,
///   sisa hari kedaluwarsa, badge status lelang, dan proses saat ini.
/// • Mendukung pull-to-refresh, loading state, empty state, dan error state dengan retry.
class SellerInventoryScreen extends StatefulWidget {
  const SellerInventoryScreen({
    super.key,
    this.repository,
  });

  final SellerRepository? repository;

  @override
  State<SellerInventoryScreen> createState() => _SellerInventoryScreenState();
}

class _SellerInventoryScreenState extends State<SellerInventoryScreen> {
  late final SellerRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  String _selectedTab = 'Aktif';
  bool _isLoading = false;
  String? _errorMessage;
  List<SellerListingItem> _items = [];
  List<CachedOrderModel> _sellerOrders = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SellerRepository.instance;
    NetworkConnectivityService.instance.addListener(_onConnectivityChanged);
    _loadData();
  }

  @override
  void dispose() {
    NetworkConnectivityService.instance.removeListener(_onConnectivityChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (!mounted) return;
    if (NetworkConnectivityService.instance.isOnline) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repository.loadInventory(forceRefresh: true);
      try {
        final ords = await OrderRepository(remoteClient: OrderApiService(client: ApiClient())).getOrders(forceRefresh: true);
        if (mounted) {
          _sellerOrders = ords;
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _items = data;
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

  List<SellerListingItem> get _filteredItems {
    var list = _items;

    final soldListingIds = _sellerOrders
        .where((o) => o.status != 'cancelled')
        .map((o) => o.listingId)
        .toSet();

    // Filter by tab
    if (_selectedTab == 'Aktif') {
      list = list.where((item) =>
        (item.status.toLowerCase() == 'active' || item.status.toLowerCase() == 'draft' || item.status.toLowerCase() == 'review') &&
        item.qty > 0 &&
        item.daysRemaining > 0
      ).toList();
    } else if (_selectedTab == 'Terjual') {
      list = list.where((item) =>
        item.status.toLowerCase() == 'sold' ||
        item.qty <= 0 ||
        item.soldQty > 0 ||
        item.ordersCount > 0 ||
        soldListingIds.contains(item.id)
      ).toList();
    } else if (_selectedTab == 'Expired') {
      list = list.where((item) =>
        item.status.toLowerCase() == 'expired' || item.daysRemaining <= 0
      ).toList();
    }

    // Filter by search query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((item) {
        return item.productName.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query) ||
            item.batchNumber.toLowerCase().contains(query);
      }).toList();
    }

    return list;
  }

  int get _activeCount {
    return _items
        .where((item) =>
            item.status.toLowerCase() == 'active' ||
            item.status.toLowerCase() == 'draft' ||
            item.status.toLowerCase() == 'review')
        .length;
  }

  void _navigateToUpload() {
    // Buyer guard check
    if (!AuthRepository.instance.isSeller) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses ditolak: Hanya penjual yang dapat mengunggah stok.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => const UploadStockFlowScreen(),
      ),
    )
        .then((_) {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterTabs(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('btn_upload_stok_fab'),
        onPressed: _navigateToUpload,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: AppColors.white),
        label: Text(
          'Upload Stok',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  // ── Header: Stok Saya + Badge + Filter Icon ──────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Stok Saya',
                    key: const Key('seller_inventory_title'),
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF03045E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_activeCount stok aktif',
                      key: const Key('seller_inventory_active_badge'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.tune_rounded,
                size: 20,
                color: Color(0xFF0F172A),
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar: Cari stok... ─────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: TextField(
          key: const Key('seller_inventory_search_field'),
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'Cari stok...',
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  // ── Filter Tabs: Semua, Aktif, Terjual, Expired ──────────────────────────
  Widget _buildFilterTabs() {
    const tabs = ['Semua', 'Aktif', 'Terjual', 'Expired'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedTab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              key: Key('tab_$tab'),
              onTap: () => setState(() => _selectedTab = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0284C7) : AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  tab,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.white
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Main Content Area ────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
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
                'Gagal Memuat Stok',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
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
                key: const Key('btn_retry_load_inventory'),
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayItems = _filteredItems;

    if (displayItems.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 36,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Stok lelang',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Mulai unggah produk pangan Anda untuk mendapatkan rekomendasi harga cerdas dan pencocokan pembeli bisnis.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.slateText,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                key: const Key('btn_empty_upload_stok'),
                onPressed: _navigateToUpload,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Upload Stok Sekarang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: AppPrefsRepository.instance,
      builder: (context, _) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
          itemCount: displayItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            return _buildInventoryCard(displayItems[index]);
          },
        );
      },
    );
  }

  // ── Inventory Card Item matching fixed reference ─────────────────────────
  Widget _buildInventoryCard(SellerListingItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('inventory_card_tap_${item.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SellerProductDetailScreen(
                item: item,
                repository: widget.repository,
              ),
            ),
          );
          if (res == true) {
            _loadData();
          }
        },
        child: Container(
          key: Key('inventory_card_${item.id}'),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Picture / Box
                  _buildProductThumbnail(item),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF03045E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.qty} ${item.defaultUnit}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Text(
                                item.formattedPrice,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                              Text(
                                ' / ${item.defaultUnit}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
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
              const SizedBox(height: 14),

              // Two Pills: Expiry + Status
              Row(
                children: [
                  // Expiry Pill
                  Flexible(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              item.daysRemainingText,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFD97706),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Pill
                  _buildStatusPill(item),
                ],
              ),
              const SizedBox(height: 12),

              // Bottom Process Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0284C7),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Proses Saat Ini:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.currentProcessLabel,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0284C7),
                        ),
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildProductThumbnail(SellerListingItem item) {
    final bgColor = _getCategoryColor(item.category);
    final iconData = _getCategoryIcon(item.category);

    Widget imageWidget;
    final img = item.imageUrl;

    if (img != null && img.isNotEmpty) {
      final cleanPath = img.replaceFirst('file://', '');
      if (img.startsWith('http://') || img.startsWith('https://')) {
        imageWidget = Image.network(
          img,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(iconData, size: 36, color: bgColor),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: bgColor,
                ),
              ),
            );
          },
        );
      } else {
        imageWidget = Image.file(
          File(cleanPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(iconData, size: 36, color: bgColor),
          ),
        );
      }
    } else {
      imageWidget = Center(
        child: Icon(iconData, size: 36, color: bgColor),
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bgColor.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget,
    );
  }

  Widget _buildStatusPill(SellerListingItem item) {
    Color bg;
    Color fg;
    Color border;
    IconData icon;

    final label = item.statusBadgeLabel;
    if (label.contains('Matching')) {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0284C7);
      border = const Color(0xFFBAE6FD);
      icon = Icons.bolt_rounded;
    } else if (label.contains('Auction')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      border = const Color(0xFFFDE68A);
      icon = Icons.attach_money_rounded;
    } else if (label.contains('Terverifikasi')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
      border = const Color(0xFFBBF7D0);
      icon = Icons.check_rounded;
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
      border = const Color(0xFFE2E8F0);
      icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('susu') || cat.contains('dairy')) {
      return const Color(0xFF0284C7);
    } else if (cat.contains('tepung') || cat.contains('grain') || cat.contains('flour')) {
      return const Color(0xFFD97706);
    } else if (cat.contains('minyak') || cat.contains('oil')) {
      return const Color(0xFF16A34A);
    } else {
      return const Color(0xFF6366F1);
    }
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('susu') || cat.contains('dairy')) {
      return Icons.local_drink_rounded;
    } else if (cat.contains('tepung') || cat.contains('grain') || cat.contains('flour')) {
      return Icons.inventory_2_rounded;
    } else if (cat.contains('minyak') || cat.contains('oil')) {
      return Icons.oil_barrel_rounded;
    } else {
      return Icons.fastfood_rounded;
    }
  }
}
