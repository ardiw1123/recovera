import 'package:flutter/material.dart';
import '../../../data/models/cached_listing_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enum: category field dari tabel `products`
// Nilai string HARUS cocok dengan nilai di kolom products.category di DB.
// ─────────────────────────────────────────────────────────────────────────────

enum FoodCategory {
  dairy('Dairy', Icons.local_drink_rounded, Color(0xFF0077B6)),
  flour('Flour & Grain', Icons.grass_rounded, Color(0xFF92400E)),
  oil('Oil', Icons.water_drop_rounded, Color(0xFFD97706)),
  frozenFood('Frozen Food', Icons.ac_unit_rounded, Color(0xFF0891B2)),
  canned('Canned', Icons.inventory_2_rounded, Color(0xFFEA580C)),
  bakery('Bakery', Icons.bakery_dining_rounded, Color(0xFFD97706)),
  beverage('Beverage', Icons.local_cafe_rounded, Color(0xFF059669));

  const FoodCategory(this.label, this.icon, this.color);

  /// Nilai yang dikirim ke / diterima dari `products.category` di database.
  final String label;
  final IconData icon;
  final Color color;

  static FoodCategory fromDb(String dbValue) {
    return FoodCategory.values.firstWhere(
      (e) => e.label.toLowerCase() == dbValue.toLowerCase(),
      orElse: () => FoodCategory.canned,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model: gabungan tabel `listings` JOIN `products` JOIN `sellers`
//
// Penamaan field SENGAJA mengikuti nama kolom di database schema supaya nanti
// pas integrasi API (fromJson) tinggal map 1-to-1 tanpa rename.
// ─────────────────────────────────────────────────────────────────────────────

class Listing {
  // ── Dari tabel `listings` ──────────────────────────────────────────────
  final int id;
  final int productId;       // listings.product_id
  final int sellerId;        // listings.seller_id
  final String batchNumber;  // listings.batch_number
  final int qty;             // listings.qty
  final double normalPrice;  // listings.normal_price
  final double startPrice;   // listings.start_price
  final double minPrice;     // listings.min_price
  final int dropIntervalMinutes; // listings.drop_interval_minutes
  final double dropPercentage;   // listings.drop_percentage
  final DateTime expiryDate;     // listings.expiry_date
  final DateTime auctionStartAt; // listings.auction_start_at
  final DateTime auctionEndAt;   // listings.auction_end_at
  final String status;           // listings.status: 'active'|'sold'|'diverted'
  final DateTime createdAt;      // listings.created_at

  // ── Dari tabel `products` (via JOIN) ───────────────────────────────────
  final String productName;    // products.name
  final String? brand;         // products.brand
  final FoodCategory category; // products.category
  final String storageType;    // products.storage_type: 'ambient'|'chilled'|'frozen'
  final String defaultUnit;    // products.default_unit
  final String? imageUrl;      // products.image_url
  final String? sku;           // products.sku

  // ── Dari tabel `sellers` (via JOIN) ───────────────────────────────────
  final String companyName;    // sellers.company_name
  final double warehouseLat;   // sellers.warehouse_lat
  final double warehouseLng;   // sellers.warehouse_lng
  final String city;           // sellers.city

  // ── Proximity Recommendation Metrics (dari backend / listings discovery) ─
  final double? distanceKm;
  final double? matchScore;
  final double? discountPct;
  final int? daysToExpiry;

  // ── Kalkulasi derived (tidak disimpan di DB, dihitung di client) ───────
  /// Sisa hari kedaluwarsa dihitung dari today sampai expiry_date.
  int get daysUntilExpiry {
    final today = DateTime.now().toLocal();
    final expiry = expiryDate.toLocal();
    return expiry.difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  /// Sisa hari yang efektif (mengutamakan backend days_to_expiry bila ada).
  int get effectiveDaysToExpiry => daysToExpiry ?? daysUntilExpiry;

  /// Persen diskon dari normal_price ke start_price.
  int get discountPercent {
    if (normalPrice <= 0) return 0;
    return ((normalPrice - startPrice) / normalPrice * 100).round();
  }

  /// Persen diskon efektif (mengutamakan backend discount_pct bila ada).
  int get effectiveDiscountPercent {
    if (discountPct != null) {
      return discountPct!.round();
    }
    return discountPercent;
  }

  /// Skor kecocokan kedekatan (proximity match score) 0.0 - 1.0.
  double get effectiveMatchScore => matchScore ?? 0.0;

  /// Label persentase kecocokan rekomendasi (contoh: '95% Match').
  String get matchScorePercentage {
    if (matchScore != null) {
      return '${(matchScore! * 100).round()}% Match';
    }
    return 'Match';
  }

  /// Format teks jarak gudang (contoh: '2.4 km').
  String get distanceText {
    if (distanceKm != null) {
      return '${distanceKm!.toStringAsFixed(1)} km';
    }
    return city;
  }

  /// Harga saat ini (start_price — nanti bisa dikurangi berdasarkan waktu Dutch Auction).
  double get currentPrice => startPrice;

  /// Apakah ini lelang Dutch (harga turun otomatis)?
  bool get isLiveDutch => status == 'active' && dropIntervalMinutes > 0;

  const Listing({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.batchNumber,
    required this.qty,
    required this.normalPrice,
    required this.startPrice,
    required this.minPrice,
    required this.dropIntervalMinutes,
    required this.dropPercentage,
    required this.expiryDate,
    required this.auctionStartAt,
    required this.auctionEndAt,
    required this.status,
    required this.createdAt,
    required this.productName,
    this.brand,
    required this.category,
    required this.storageType,
    required this.defaultUnit,
    this.imageUrl,
    this.sku,
    required this.companyName,
    required this.warehouseLat,
    required this.warehouseLng,
    required this.city,
    this.distanceKm,
    this.matchScore,
    this.discountPct,
    this.daysToExpiry,
  });

  /// Factory constructor dari JSON API (nama key = nama kolom DB / ListingResponse).
  factory Listing.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return Listing(
      // listings fields
      id: json['id'] as int,
      productId: json['product_id'] as int? ?? 1,
      sellerId: json['seller_id'] as int? ?? 1,
      batchNumber: json['batch_number'] as String? ?? '',
      qty: json['qty'] as int? ?? 0,
      normalPrice: (json['normal_price'] as num?)?.toDouble() ?? 0.0,
      startPrice: (json['start_price'] as num?)?.toDouble() ?? (json['current_price'] as num?)?.toDouble() ?? 0.0,
      minPrice: (json['min_price'] as num?)?.toDouble() ?? 0.0,
      dropIntervalMinutes: json['drop_interval_minutes'] as int? ?? 60,
      dropPercentage: (json['drop_percentage'] as num?)?.toDouble() ?? 2.5,
      expiryDate: DateTime.tryParse(json['expiry_date'] as String? ?? '') ?? DateTime.now(),
      auctionStartAt: DateTime.tryParse(json['auction_start_at'] as String? ?? '') ?? DateTime.now(),
      auctionEndAt: DateTime.tryParse(json['auction_end_at'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      // products fields (joined or nested)
      productName: (product?['name'] as String?) ?? json['name'] as String? ?? json['product_name'] as String? ?? 'Produk',
      brand: (product?['brand'] as String?) ?? json['brand'] as String?,
      category: FoodCategory.fromDb((product?['category'] as String?) ?? json['category'] as String? ?? 'General'),
      storageType: (product?['storage_type'] as String?) ?? json['storage_type'] as String? ?? 'ambient',
      defaultUnit: (product?['default_unit'] as String?) ?? json['default_unit'] as String? ?? 'pcs',
      imageUrl: (product?['image_url'] as String?) ?? json['image_url'] as String?,
      sku: (product?['sku'] as String?) ?? json['sku'] as String?,
      // sellers fields (joined or nested)
      companyName: json['seller_company'] as String? ?? json['company_name'] as String? ?? 'Distributor',
      warehouseLat: (json['warehouse_lat'] as num?)?.toDouble() ?? -6.2088,
      warehouseLng: (json['warehouse_lng'] as num?)?.toDouble() ?? 106.8456,
      city: json['warehouse_city'] as String? ?? json['city'] as String? ?? 'Jakarta',
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      matchScore: (json['match_score'] as num?)?.toDouble(),
      discountPct: (json['discount_pct'] as num?)?.toDouble(),
      daysToExpiry: (json['days_to_expiry'] as num?)?.toInt(),
    );
  }

  /// Factory constructor dari CachedListingModel (SQLite cache / remote API)
  factory Listing.fromCachedModel(CachedListingModel model) {
    return Listing(
      id: model.id,
      productId: model.productId,
      sellerId: model.sellerId,
      batchNumber: model.batchNumber,
      qty: model.qty,
      normalPrice: model.normalPrice,
      startPrice: model.startPrice,
      minPrice: model.minPrice,
      dropIntervalMinutes: model.dropIntervalMinutes,
      dropPercentage: model.dropPercentage,
      expiryDate: DateTime.tryParse(model.expiryDate) ?? DateTime.now(),
      auctionStartAt: DateTime.tryParse(model.auctionStartAt) ?? DateTime.now(),
      auctionEndAt: DateTime.tryParse(model.auctionEndAt) ?? DateTime.now(),
      status: model.status,
      createdAt: DateTime.tryParse(model.createdAt) ?? DateTime.now(),
      productName: model.productName,
      brand: model.brand,
      category: FoodCategory.fromDb(model.category),
      storageType: model.storageType,
      defaultUnit: model.defaultUnit,
      imageUrl: model.imageUrl,
      sku: null,
      companyName: model.sellerCompany ?? '',
      warehouseLat: model.warehouseLat ?? -6.2088,
      warehouseLng: model.warehouseLng ?? 106.8456,
      city: model.warehouseCity ?? 'Jakarta',
      distanceKm: model.distanceKm,
      matchScore: model.matchScore,
      discountPct: model.discountPct,
      daysToExpiry: model.daysToExpiry,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'seller_id': sellerId,
        'batch_number': batchNumber,
        'qty': qty,
        'normal_price': normalPrice,
        'start_price': startPrice,
        'min_price': minPrice,
        'drop_interval_minutes': dropIntervalMinutes,
        'drop_percentage': dropPercentage,
        'expiry_date': expiryDate.toIso8601String(),
        'auction_start_at': auctionStartAt.toIso8601String(),
        'auction_end_at': auctionEndAt.toIso8601String(),
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'name': productName,
        'brand': brand,
        'category': category.label,
        'storage_type': storageType,
        'default_unit': defaultUnit,
        'image_url': imageUrl,
        'sku': sku,
        'company_name': companyName,
        'warehouse_lat': warehouseLat,
        'warehouse_lng': warehouseLng,
        'city': city,
        'distance_km': distanceKm,
        'match_score': matchScore,
        'discount_pct': discountPct,
        'days_to_expiry': daysToExpiry,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Dummy data — field name sesuai schema DB
// ─────────────────────────────────────────────────────────────────────────────

final List<Listing> dummyListings = [
  Listing(
    id: 1,
    productId: 101,
    sellerId: 1,
    batchNumber: 'BTH-2024-001',
    qty: 120,
    normalPrice: 15000,
    startPrice: 8250,
    minPrice: 6000,
    dropIntervalMinutes: 60,
    dropPercentage: 2.50,
    expiryDate: DateTime.now().add(const Duration(days: 5)),
    auctionStartAt: DateTime.now().subtract(const Duration(hours: 2)),
    auctionEndAt: DateTime.now().add(const Duration(days: 4)),
    status: 'active',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    productName: 'Susu UHT Whole Milk Freshland 1L',
    brand: 'Freshland',
    category: FoodCategory.dairy,
    storageType: 'chilled',
    defaultUnit: 'box',
    imageUrl: null,
    sku: 'FRH-SUSU-001',
    companyName: 'PT Maju Pangan Abadi',
    warehouseLat: -6.3632,
    warehouseLng: 106.8319,
    city: 'Cimanggis',
  ),
  Listing(
    id: 2,
    productId: 202,
    sellerId: 2,
    batchNumber: 'BTH-2024-002',
    qty: 80,
    normalPrice: 38000,
    startPrice: 23500,
    minPrice: 18000,
    dropIntervalMinutes: 90,
    dropPercentage: 3.00,
    expiryDate: DateTime.now().add(const Duration(days: 3)),
    auctionStartAt: DateTime.now().subtract(const Duration(hours: 5)),
    auctionEndAt: DateTime.now().add(const Duration(days: 2)),
    status: 'active',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    productName: 'Minyak Goreng Kelapa Sawit Pouch 2L',
    brand: 'Sania',
    category: FoodCategory.oil,
    storageType: 'ambient',
    defaultUnit: 'box',
    imageUrl: null,
    sku: 'BRK-MGS-002',
    companyName: 'CV Berkah Nabati',
    warehouseLat: -6.4025,
    warehouseLng: 106.7942,
    city: 'Depok',
  ),
  Listing(
    id: 3,
    productId: 303,
    sellerId: 3,
    batchNumber: 'BTH-2024-003',
    qty: 30,
    normalPrice: 160000,
    startPrice: 79900,
    minPrice: 65000,
    dropIntervalMinutes: 120,
    dropPercentage: 2.00,
    expiryDate: DateTime.now().add(const Duration(days: 8)),
    auctionStartAt: DateTime.now().subtract(const Duration(hours: 1)),
    auctionEndAt: DateTime.now().add(const Duration(days: 7)),
    status: 'active',
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    productName: 'Keju Cheddar Olahan Blok Bakery 2kg',
    brand: 'Kraft',
    category: FoodCategory.dairy,
    storageType: 'chilled',
    defaultUnit: 'blok',
    imageUrl: null,
    sku: 'PRD-KJC-003',
    companyName: 'PT Prima Dairy Food',
    warehouseLat: -6.3741,
    warehouseLng: 106.8296,
    city: 'Margonda',
  ),
  Listing(
    id: 4,
    productId: 404,
    sellerId: 4,
    batchNumber: 'BTH-2024-004',
    qty: 15,
    normalPrice: 210000,
    startPrice: 147000,
    minPrice: 120000,
    dropIntervalMinutes: 60,
    dropPercentage: 2.50,
    expiryDate: DateTime.now().add(const Duration(days: 12)),
    auctionStartAt: DateTime.now().subtract(const Duration(hours: 3)),
    auctionEndAt: DateTime.now().add(const Duration(days: 11)),
    status: 'active',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    productName: 'Tepung Terigu Protein Tinggi 25kg',
    brand: 'Cakra Kembar',
    category: FoodCategory.flour,
    storageType: 'ambient',
    defaultUnit: 'sak',
    imageUrl: null,
    sku: 'BGS-TPG-004',
    companyName: 'PT Bogasari Flour Mills',
    warehouseLat: -6.5273,
    warehouseLng: 106.8067,
    city: 'Bogor',
  ),
  Listing(
    id: 5,
    productId: 505,
    sellerId: 5,
    batchNumber: 'BTH-2024-005',
    qty: 200,
    normalPrice: 65000,
    startPrice: 39000,
    minPrice: 30000,
    dropIntervalMinutes: 45,
    dropPercentage: 3.50,
    expiryDate: DateTime.now().add(const Duration(days: 7)),
    auctionStartAt: DateTime.now().subtract(const Duration(hours: 4)),
    auctionEndAt: DateTime.now().add(const Duration(days: 6)),
    status: 'active',
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    productName: 'Nugget Ayam Fiesta 1kg',
    brand: 'Fiesta',
    category: FoodCategory.frozenFood,
    storageType: 'frozen',
    defaultUnit: 'pack',
    imageUrl: null,
    sku: 'CPF-NGT-005',
    companyName: 'PT Charoen Pokphand',
    warehouseLat: -6.4773,
    warehouseLng: 106.8607,
    city: 'Cibinong',
  ),
  Listing(
    id: 6,
    productId: 606,
    sellerId: 6,
    batchNumber: 'BTH-2024-006',
    qty: 500,
    normalPrice: 22000,
    startPrice: 14300,
    minPrice: 10000,
    dropIntervalMinutes: 120,
    dropPercentage: 2.00,
    expiryDate: DateTime.now().add(const Duration(days: 14)),
    auctionStartAt: DateTime.now().subtract(const Duration(hours: 6)),
    auctionEndAt: DateTime.now().add(const Duration(days: 13)),
    status: 'active',
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
    productName: 'Sarden Kaleng ABC 425g',
    brand: 'ABC',
    category: FoodCategory.canned,
    storageType: 'ambient',
    defaultUnit: 'kaleng',
    imageUrl: null,
    sku: 'HAB-SRD-006',
    companyName: 'PT Heinz ABC Indonesia',
    warehouseLat: -6.2343,
    warehouseLng: 106.9921,
    city: 'Bekasi',
  ),
];

// Alias untuk backward-compat kalau ada kode lama yang masih pakai `Product`
// HAPUS ini setelah semua file sudah dimigrasi ke `Listing`
typedef Product = Listing;
final List<Listing> dummyProducts = dummyListings;
