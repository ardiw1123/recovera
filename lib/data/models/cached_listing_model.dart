import '../database/database_constants.dart';

/// Data model representing a cached listing row in SQLite table `cached_listings`.
/// Used for offline browsing, searching, and filtering per US-05 and US-12.
class CachedListingModel {
  final int id;
  final int productId;
  final int sellerId;
  final String batchNumber;
  final int qty;
  final double normalPrice;
  final double startPrice;
  final double minPrice;
  final double currentPrice;
  final int dropIntervalMinutes;
  final double dropPercentage;
  final String expiryDate;
  final String auctionStartAt;
  final String auctionEndAt;
  final String status;
  final String createdAt;

  // Denormalized fields for offline display without JOIN
  final String productName;
  final String? brand;
  final String category;
  final String storageType;
  final String defaultUnit;
  final String? imageUrl;
  final String? sellerCompany;
  final double? warehouseLat;
  final double? warehouseLng;
  final String? warehouseCity;
  final double? distanceKm;
  final String cachedAt;

  const CachedListingModel({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.batchNumber,
    required this.qty,
    required this.normalPrice,
    required this.startPrice,
    required this.minPrice,
    required this.currentPrice,
    this.dropIntervalMinutes = 60,
    this.dropPercentage = 2.50,
    required this.expiryDate,
    required this.auctionStartAt,
    required this.auctionEndAt,
    this.status = 'active',
    required this.createdAt,
    required this.productName,
    this.brand,
    required this.category,
    this.storageType = 'ambient',
    this.defaultUnit = 'pcs',
    this.imageUrl,
    this.sellerCompany,
    this.warehouseLat,
    this.warehouseLng,
    this.warehouseCity,
    this.distanceKm,
    required this.cachedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colListingId: id,
      DatabaseConstants.colListingProductId: productId,
      DatabaseConstants.colListingSellerId: sellerId,
      DatabaseConstants.colListingBatchNumber: batchNumber,
      DatabaseConstants.colListingQty: qty,
      DatabaseConstants.colListingNormalPrice: normalPrice,
      DatabaseConstants.colListingStartPrice: startPrice,
      DatabaseConstants.colListingMinPrice: minPrice,
      DatabaseConstants.colListingCurrentPrice: currentPrice,
      DatabaseConstants.colListingDropIntervalMinutes: dropIntervalMinutes,
      DatabaseConstants.colListingDropPercentage: dropPercentage,
      DatabaseConstants.colListingExpiryDate: expiryDate,
      DatabaseConstants.colListingAuctionStartAt: auctionStartAt,
      DatabaseConstants.colListingAuctionEndAt: auctionEndAt,
      DatabaseConstants.colListingStatus: status,
      DatabaseConstants.colListingCreatedAt: createdAt,
      DatabaseConstants.colListingProductName: productName,
      DatabaseConstants.colListingBrand: brand,
      DatabaseConstants.colListingCategory: category,
      DatabaseConstants.colListingStorageType: storageType,
      DatabaseConstants.colListingDefaultUnit: defaultUnit,
      DatabaseConstants.colListingImageUrl: imageUrl,
      DatabaseConstants.colListingSellerCompany: sellerCompany,
      DatabaseConstants.colListingWarehouseLat: warehouseLat,
      DatabaseConstants.colListingWarehouseLng: warehouseLng,
      DatabaseConstants.colListingWarehouseCity: warehouseCity,
      DatabaseConstants.colListingDistanceKm: distanceKm,
      DatabaseConstants.colListingCachedAt: cachedAt,
    };
  }

  factory CachedListingModel.fromMap(Map<String, dynamic> map) {
    return CachedListingModel(
      id: map[DatabaseConstants.colListingId] as int,
      productId: map[DatabaseConstants.colListingProductId] as int,
      sellerId: map[DatabaseConstants.colListingSellerId] as int,
      batchNumber: map[DatabaseConstants.colListingBatchNumber] as String,
      qty: map[DatabaseConstants.colListingQty] as int,
      normalPrice: (map[DatabaseConstants.colListingNormalPrice] as num).toDouble(),
      startPrice: (map[DatabaseConstants.colListingStartPrice] as num).toDouble(),
      minPrice: (map[DatabaseConstants.colListingMinPrice] as num).toDouble(),
      currentPrice: (map[DatabaseConstants.colListingCurrentPrice] as num).toDouble(),
      dropIntervalMinutes: (map[DatabaseConstants.colListingDropIntervalMinutes] as int?) ?? 60,
      dropPercentage: ((map[DatabaseConstants.colListingDropPercentage] as num?) ?? 2.50).toDouble(),
      expiryDate: map[DatabaseConstants.colListingExpiryDate] as String,
      auctionStartAt: map[DatabaseConstants.colListingAuctionStartAt] as String,
      auctionEndAt: map[DatabaseConstants.colListingAuctionEndAt] as String,
      status: (map[DatabaseConstants.colListingStatus] as String?) ?? 'active',
      createdAt: map[DatabaseConstants.colListingCreatedAt] as String,
      productName: map[DatabaseConstants.colListingProductName] as String,
      brand: map[DatabaseConstants.colListingBrand] as String?,
      category: map[DatabaseConstants.colListingCategory] as String,
      storageType: (map[DatabaseConstants.colListingStorageType] as String?) ?? 'ambient',
      defaultUnit: (map[DatabaseConstants.colListingDefaultUnit] as String?) ?? 'pcs',
      imageUrl: map[DatabaseConstants.colListingImageUrl] as String?,
      sellerCompany: map[DatabaseConstants.colListingSellerCompany] as String?,
      warehouseLat: (map[DatabaseConstants.colListingWarehouseLat] as num?)?.toDouble(),
      warehouseLng: (map[DatabaseConstants.colListingWarehouseLng] as num?)?.toDouble(),
      warehouseCity: map[DatabaseConstants.colListingWarehouseCity] as String?,
      distanceKm: (map[DatabaseConstants.colListingDistanceKm] as num?)?.toDouble(),
      cachedAt: map[DatabaseConstants.colListingCachedAt] as String,
    );
  }

  /// Construct from remote API ListingResponse JSON
  factory CachedListingModel.fromApiResponse(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return CachedListingModel(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      sellerId: json['seller_id'] as int,
      batchNumber: json['batch_number'] as String,
      qty: json['qty'] as int,
      normalPrice: (json['normal_price'] as num).toDouble(),
      startPrice: (json['start_price'] as num).toDouble(),
      minPrice: (json['min_price'] as num).toDouble(),
      currentPrice: (json['current_price'] as num).toDouble(),
      dropIntervalMinutes: (json['drop_interval_minutes'] as int?) ?? 60,
      dropPercentage: ((json['drop_percentage'] as num?) ?? 2.50).toDouble(),
      expiryDate: json['expiry_date'] as String,
      auctionStartAt: json['auction_start_at'] as String,
      auctionEndAt: json['auction_end_at'] as String,
      status: (json['status'] as String?) ?? 'active',
      createdAt: json['created_at'] as String,
      productName: (product?['name'] as String?) ?? json['product_name'] as String? ?? '',
      brand: (product?['brand'] as String?) ?? json['brand'] as String?,
      category: (product?['category'] as String?) ?? json['category'] as String? ?? 'General',
      storageType: (product?['storage_type'] as String?) ?? json['storage_type'] as String? ?? 'ambient',
      defaultUnit: (product?['default_unit'] as String?) ?? json['default_unit'] as String? ?? 'pcs',
      imageUrl: (product?['image_url'] as String?) ?? json['image_url'] as String?,
      sellerCompany: json['seller_company'] as String?,
      warehouseLat: (json['warehouse_lat'] as num?)?.toDouble(),
      warehouseLng: (json['warehouse_lng'] as num?)?.toDouble(),
      warehouseCity: json['warehouse_city'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      cachedAt: DateTime.now().toIso8601String(),
    );
  }

  CachedListingModel copyWith({
    int? id,
    int? productId,
    int? sellerId,
    String? batchNumber,
    int? qty,
    double? normalPrice,
    double? startPrice,
    double? minPrice,
    double? currentPrice,
    int? dropIntervalMinutes,
    double? dropPercentage,
    String? expiryDate,
    String? auctionStartAt,
    String? auctionEndAt,
    String? status,
    String? createdAt,
    String? productName,
    String? brand,
    String? category,
    String? storageType,
    String? defaultUnit,
    String? imageUrl,
    String? sellerCompany,
    double? warehouseLat,
    double? warehouseLng,
    String? warehouseCity,
    double? distanceKm,
    String? cachedAt,
  }) {
    return CachedListingModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sellerId: sellerId ?? this.sellerId,
      batchNumber: batchNumber ?? this.batchNumber,
      qty: qty ?? this.qty,
      normalPrice: normalPrice ?? this.normalPrice,
      startPrice: startPrice ?? this.startPrice,
      minPrice: minPrice ?? this.minPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      dropIntervalMinutes: dropIntervalMinutes ?? this.dropIntervalMinutes,
      dropPercentage: dropPercentage ?? this.dropPercentage,
      expiryDate: expiryDate ?? this.expiryDate,
      auctionStartAt: auctionStartAt ?? this.auctionStartAt,
      auctionEndAt: auctionEndAt ?? this.auctionEndAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      storageType: storageType ?? this.storageType,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerCompany: sellerCompany ?? this.sellerCompany,
      warehouseLat: warehouseLat ?? this.warehouseLat,
      warehouseLng: warehouseLng ?? this.warehouseLng,
      warehouseCity: warehouseCity ?? this.warehouseCity,
      distanceKm: distanceKm ?? this.distanceKm,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}
