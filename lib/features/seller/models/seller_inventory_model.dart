// Data models for the Recovera seller inventory, draft creation, validation,
// recommendation, and publication workflow.
import '../../../data/repositories/app_prefs_repository.dart';

class SellerListingItem {
  final int id;
  final int productId;
  final int? sellerId;
  final String batchNumber;
  final int qty;
  final double normalPrice;
  final double startPrice;
  final double minPrice;
  final double currentPrice;
  final String expiryDate;
  final String status;
  final String createdAt;
  final String productName;
  final String category;
  final String? brand;
  final String storageType;
  final String defaultUnit;
  final String? imageUrl;
  final String? sellerCompany;
  final double? warehouseLat;
  final double? warehouseLng;
  final String? warehouseCity;
  final double? distanceKm;

  const SellerListingItem({
    required this.id,
    required this.productId,
    this.sellerId,
    required this.batchNumber,
    required this.qty,
    required this.normalPrice,
    required this.startPrice,
    required this.minPrice,
    required this.currentPrice,
    required this.expiryDate,
    required this.status,
    required this.createdAt,
    required this.productName,
    required this.category,
    this.brand,
    this.storageType = 'ambient',
    this.defaultUnit = 'box',
    this.imageUrl,
    this.sellerCompany,
    this.warehouseLat,
    this.warehouseLng,
    this.warehouseCity,
    this.distanceKm,
  });

  factory SellerListingItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;

    return SellerListingItem(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      productId: json['product_id'] is int
          ? json['product_id'] as int
          : int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      sellerId: json['seller_id'] is int
          ? json['seller_id'] as int
          : int.tryParse(json['seller_id']?.toString() ?? ''),
      batchNumber: json['batch_number'] as String? ?? '',
      qty: json['qty'] is int
          ? json['qty'] as int
          : int.tryParse(json['qty']?.toString() ?? '1') ?? 1,
      normalPrice: (json['normal_price'] as num?)?.toDouble() ?? 0.0,
      startPrice: (json['start_price'] as num?)?.toDouble() ?? 0.0,
      minPrice: (json['min_price'] as num?)?.toDouble() ?? 0.0,
      currentPrice: (json['current_price'] as num?)?.toDouble() ??
          (json['start_price'] as num?)?.toDouble() ??
          0.0,
      expiryDate: json['expiry_date'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] as String? ?? '',
      productName: (product?['name'] as String?) ??
          json['product_name'] as String? ??
          'Produk Pangan',
      category: (product?['category'] as String?) ??
          json['category'] as String? ??
          'Umum',
      brand: (product?['brand'] as String?) ?? json['brand'] as String?,
      storageType: (product?['storage_type'] as String?) ??
          json['storage_type'] as String? ??
          'ambient',
      defaultUnit: (product?['default_unit'] as String?) ??
          json['default_unit'] as String? ??
          'box',
      imageUrl: (product?['image_url'] as String?) ?? json['image_url'] as String?,
      sellerCompany: json['seller_company'] as String?,
      warehouseLat: (json['warehouse_lat'] as num?)?.toDouble(),
      warehouseLng: (json['warehouse_lng'] as num?)?.toDouble(),
      warehouseCity: json['warehouse_city'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  int get daysRemaining {
    try {
      final exp = DateTime.parse(expiryDate);
      final now = DateTime.now();
      final diff = exp.difference(DateTime(now.year, now.month, now.day)).inDays;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 30;
    }
  }

  String get daysRemainingText => '$daysRemaining hari tersisa';

  bool get isPublished => status.toLowerCase() == 'active';
  double get discountPercentage => normalPrice > 0
      ? (((normalPrice - (currentPrice > 0 ? currentPrice : startPrice)) / normalPrice) * 100)
          .clamp(0, 99)
          .toDouble()
      : 0.0;
  String get displayStatusLabel => statusBadgeLabel;

  String get formattedPrice => formatCurrency(currentPrice > 0 ? currentPrice : startPrice);
  String get formattedNormalPrice => formatCurrency(normalPrice);
  String get formattedStartPrice => formatCurrency(startPrice);
  String get formattedMinPrice => formatCurrency(minPrice);

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        if (sellerId != null) 'seller_id': sellerId,
        'batch_number': batchNumber,
        'qty': qty,
        'normal_price': normalPrice,
        'start_price': startPrice,
        'min_price': minPrice,
        'current_price': currentPrice,
        'expiry_date': expiryDate,
        'status': status,
        'created_at': createdAt,
        'product': {
          'id': productId,
          'name': productName,
          'category': category,
          if (brand != null) 'brand': brand,
          'storage_type': storageType,
          'default_unit': defaultUnit,
          if (imageUrl != null) 'image_url': imageUrl,
        },
        if (sellerCompany != null) 'seller_company': sellerCompany,
        if (warehouseLat != null) 'warehouse_lat': warehouseLat,
        if (warehouseLng != null) 'warehouse_lng': warehouseLng,
        if (warehouseCity != null) 'warehouse_city': warehouseCity,
        if (distanceKm != null) 'distance_km': distanceKm,
      };

  String get statusBadgeLabel {
    switch (status.toLowerCase()) {
      case 'active':
        if (id % 3 == 0) return 'Status: Matching';
        if (id % 3 == 1) return 'Status: Auction';
        return 'Status: Terverifikasi';
      case 'draft':
        return 'Status: Draft';
      case 'review':
        return 'Status: Siap Review';
      case 'sold':
        return 'Status: Terjual';
      case 'expired':
        return 'Status: Expired';
      default:
        return 'Status: $status';
    }
  }

  String get currentProcessLabel {
    switch (status.toLowerCase()) {
      case 'active':
        if (id % 3 == 0) return 'Pencocokan Pembeli Bisnis';
        if (id % 3 == 1) return 'Dutch Auction Berlangsung';
        return 'Siap Serap Pasar';
      case 'draft':
        return 'Pemeriksaan Draft Produk';
      case 'review':
        return 'Menunggu Konfirmasi Publikasi';
      case 'sold':
        return 'Pesanan Diselesaikan';
      case 'expired':
        return 'Masa Simpan Selesai';
      default:
        return 'Diproses Sistem';
    }
  }
}

/// Payload to create a new draft listing with backend standards
class SellerDraftCreatePayload {
  final String sku;
  final String name;
  final String category;
  final String storageType;
  final String defaultUnit;
  final String imageUrl;
  final String? brand;
  final String? barcode;
  final String batchNumber;
  final int qty;
  final double normalPrice;
  final double minPrice;
  final String expiryDate; // YYYY-MM-DD

  const SellerDraftCreatePayload({
    required this.sku,
    required this.name,
    required this.category,
    this.storageType = 'ambient',
    required this.defaultUnit,
    required this.imageUrl,
    this.brand,
    this.barcode,
    required this.batchNumber,
    required this.qty,
    required this.normalPrice,
    required this.minPrice,
    required this.expiryDate,
  });

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'name': name,
        'category': category,
        'storage_type': storageType,
        'default_unit': defaultUnit,
        'image_url': imageUrl,
        if (brand != null && brand!.isNotEmpty) 'brand': brand,
        if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
        'batch_number': batchNumber,
        'qty': qty,
        'normal_price': normalPrice,
        'min_price': minPrice,
        'expiry_date': expiryDate,
      };
}

/// Automatic product validation result
class SellerValidationResult {
  final bool isValid;
  final List<String> errors;
  final String status;

  const SellerValidationResult({
    required this.isValid,
    required this.errors,
    required this.status,
  });

  factory SellerValidationResult.fromJson(Map<String, dynamic> json) {
    final errs = json['errors'] as List<dynamic>? ?? [];
    return SellerValidationResult(
      isValid: json['valid'] == true,
      errors: errs.map((e) => e.toString()).toList(),
      status: json['status'] as String? ?? 'review',
    );
  }
}

/// AI price advice recommendation response
class SellerRecommendationResult {
  final double suggestedPrice;
  final double discountPct;
  final String rationale;
  final String nextDropAt;
  final bool hasPriceWarning;
  final double minAcceptedPrice;
  final double maxAcceptedPrice;

  const SellerRecommendationResult({
    required this.suggestedPrice,
    required this.discountPct,
    required this.rationale,
    required this.nextDropAt,
    required this.hasPriceWarning,
    required this.minAcceptedPrice,
    required this.maxAcceptedPrice,
  });

  factory SellerRecommendationResult.fromJson(Map<String, dynamic> json) {
    final rec = json['recommendation'] as Map<String, dynamic>? ?? json;
    final accepted = json['accepted_range'] as Map<String, dynamic>? ?? {};

    return SellerRecommendationResult(
      suggestedPrice: (rec['suggested_price'] as num?)?.toDouble() ?? 0.0,
      discountPct: (rec['discount_pct'] as num?)?.toDouble() ?? 0.0,
      rationale: rec['rationale'] as String? ?? '',
      nextDropAt: rec['next_drop_at'] as String? ?? '',
      hasPriceWarning: json['price_warning'] == true,
      minAcceptedPrice: (accepted['minimum'] as num?)?.toDouble() ??
          ((rec['suggested_price'] as num?)?.toDouble() ?? 0.0) * 0.8,
      maxAcceptedPrice: (accepted['maximum'] as num?)?.toDouble() ??
          ((rec['suggested_price'] as num?)?.toDouble() ?? 0.0) * 1.2,
    );
  }
}

/// Helper currency formatter delegating to AppPrefsRepository for multi-currency support
String formatCurrency(num amount) {
  return AppPrefsRepository.instance.formatPrice(amount.toDouble());
}
