import '../database/database_constants.dart';

/// Data model representing a cached order in SQLite table `cached_orders`.
/// Supports offline order details and compass navigation via warehouse_lat/lng.
class CachedOrderModel {
  final int id;
  final int listingId;
  final int buyerId;
  final int qty;
  final double finalUnitPrice;
  final double totalPrice;
  final String status;
  final String createdAt;

  // Joined/denormalized fields for offline guidance
  final String productName;
  final String category;
  final String batchNumber;
  final double? warehouseLat;
  final double? warehouseLng;
  final String? warehouseAddress;
  final String cachedAt;
  final String? imageUrl;
  final String? buyerName;
  final String? buyerBusinessType;
  final String? sellerName;

  const CachedOrderModel({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.qty,
    required this.finalUnitPrice,
    required this.totalPrice,
    this.status = 'paid',
    required this.createdAt,
    required this.productName,
    required this.category,
    required this.batchNumber,
    this.warehouseLat,
    this.warehouseLng,
    this.warehouseAddress,
    required this.cachedAt,
    this.imageUrl,
    this.buyerName,
    this.buyerBusinessType,
    this.sellerName,
  });

  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colOrderId: id,
      DatabaseConstants.colOrderListingId: listingId,
      DatabaseConstants.colOrderBuyerId: buyerId,
      DatabaseConstants.colOrderQty: qty,
      DatabaseConstants.colOrderFinalUnitPrice: finalUnitPrice,
      DatabaseConstants.colOrderTotalPrice: totalPrice,
      DatabaseConstants.colOrderStatus: status,
      DatabaseConstants.colOrderCreatedAt: createdAt,
      DatabaseConstants.colOrderProductName: productName,
      DatabaseConstants.colOrderCategory: category,
      DatabaseConstants.colOrderBatchNumber: batchNumber,
      DatabaseConstants.colOrderWarehouseLat: warehouseLat,
      DatabaseConstants.colOrderWarehouseLng: warehouseLng,
      DatabaseConstants.colOrderWarehouseAddress: warehouseAddress,
      DatabaseConstants.colOrderCachedAt: cachedAt,
    };
  }

  factory CachedOrderModel.fromMap(Map<String, dynamic> map) {
    return CachedOrderModel(
      id: map[DatabaseConstants.colOrderId] as int,
      listingId: map[DatabaseConstants.colOrderListingId] as int,
      buyerId: map[DatabaseConstants.colOrderBuyerId] as int,
      qty: map[DatabaseConstants.colOrderQty] as int,
      finalUnitPrice: (map[DatabaseConstants.colOrderFinalUnitPrice] as num).toDouble(),
      totalPrice: (map[DatabaseConstants.colOrderTotalPrice] as num).toDouble(),
      status: (map[DatabaseConstants.colOrderStatus] as String?) ?? 'paid',
      createdAt: map[DatabaseConstants.colOrderCreatedAt] as String,
      productName: map[DatabaseConstants.colOrderProductName] as String,
      category: map[DatabaseConstants.colOrderCategory] as String,
      batchNumber: map[DatabaseConstants.colOrderBatchNumber] as String,
      warehouseLat: (map[DatabaseConstants.colOrderWarehouseLat] as num?)?.toDouble(),
      warehouseLng: (map[DatabaseConstants.colOrderWarehouseLng] as num?)?.toDouble(),
      warehouseAddress: map[DatabaseConstants.colOrderWarehouseAddress] as String?,
      cachedAt: map[DatabaseConstants.colOrderCachedAt] as String,
    );
  }

  /// Construct from remote API OrderResponse JSON
  factory CachedOrderModel.fromApiResponse(Map<String, dynamic> json) {
    final detail = json['product_detail'] as Map<String, dynamic>?;
    return CachedOrderModel(
      id: json['id'] as int,
      listingId: json['listing_id'] as int,
      buyerId: json['buyer_id'] as int,
      qty: json['qty'] as int,
      finalUnitPrice: (json['final_unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      status: (json['status'] as String?) ?? 'paid',
      createdAt: json['created_at'] as String,
      productName: (detail?['product_name'] as String?) ?? '',
      category: (detail?['category'] as String?) ?? 'General',
      batchNumber: (detail?['batch_number'] as String?) ?? '',
      warehouseLat: (detail?['warehouse_lat'] as num?)?.toDouble(),
      warehouseLng: (detail?['warehouse_lng'] as num?)?.toDouble(),
      warehouseAddress: detail?['warehouse_address'] as String?,
      cachedAt: DateTime.now().toIso8601String(),
      imageUrl: (detail?['image_url'] as String?) ?? (json['image_url'] as String?),
      buyerName: (json['buyer_name'] as String?) ?? (detail?['buyer_name'] as String?),
      buyerBusinessType: (json['buyer_business_type'] as String?) ?? (detail?['buyer_business_type'] as String?),
      sellerName: (json['seller_name'] as String?) ?? (detail?['seller_name'] as String?),
    );
  }

  CachedOrderModel copyWith({
    int? id,
    int? listingId,
    int? buyerId,
    int? qty,
    double? finalUnitPrice,
    double? totalPrice,
    String? status,
    String? createdAt,
    String? productName,
    String? category,
    String? batchNumber,
    double? warehouseLat,
    double? warehouseLng,
    String? warehouseAddress,
    String? cachedAt,
    String? imageUrl,
    String? buyerName,
    String? buyerBusinessType,
    String? sellerName,
  }) {
    return CachedOrderModel(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      buyerId: buyerId ?? this.buyerId,
      qty: qty ?? this.qty,
      finalUnitPrice: finalUnitPrice ?? this.finalUnitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      batchNumber: batchNumber ?? this.batchNumber,
      warehouseLat: warehouseLat ?? this.warehouseLat,
      warehouseLng: warehouseLng ?? this.warehouseLng,
      warehouseAddress: warehouseAddress ?? this.warehouseAddress,
      cachedAt: cachedAt ?? this.cachedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      buyerName: buyerName ?? this.buyerName,
      buyerBusinessType: buyerBusinessType ?? this.buyerBusinessType,
      sellerName: sellerName ?? this.sellerName,
    );
  }
}
