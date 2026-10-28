import '../../../data/models/cached_order_model.dart';

/// Ekstensi dan model pendukung untuk tampilan Riwayat Transaksi (Buyer & Seller)
class TransactionOrder {
  final int id;
  final String orderCode;
  final int listingId;
  final String productName;
  final String category;
  final String batchNumber;
  final String imageUrl;
  final int qty;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final String status; // 'paid', 'in_progress', 'picked_up', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime? pickupDeadline;

  // Info Mitra / Gudang
  final String partnerName; // Seller company name (for Buyer) or Buyer company name (for Seller)
  final String? partnerSubtitle;
  final bool isVerifiedPartner;
  final double? distanceKm;
  final String? warehouseName;
  final String? warehouseAddress;
  final double? warehouseLat;
  final double? warehouseLng;
  final String? verificationCode;
  final String? deliveryNote;

  const TransactionOrder({
    required this.id,
    required this.orderCode,
    required this.listingId,
    required this.productName,
    required this.category,
    required this.batchNumber,
    required this.imageUrl,
    required this.qty,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.pickupDeadline,
    required this.partnerName,
    this.partnerSubtitle,
    this.isVerifiedPartner = true,
    this.distanceKm,
    this.warehouseName,
    this.warehouseAddress,
    this.warehouseLat,
    this.warehouseLng,
    this.verificationCode,
    this.deliveryNote,
  });

  TransactionOrder copyWith({
    String? status,
    DateTime? pickupDeadline,
    String? verificationCode,
  }) {
    return TransactionOrder(
      id: id,
      orderCode: orderCode,
      listingId: listingId,
      productName: productName,
      category: category,
      batchNumber: batchNumber,
      imageUrl: imageUrl,
      qty: qty,
      unit: unit,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      status: status ?? this.status,
      createdAt: createdAt,
      pickupDeadline: pickupDeadline ?? this.pickupDeadline,
      partnerName: partnerName,
      partnerSubtitle: partnerSubtitle,
      isVerifiedPartner: isVerifiedPartner,
      distanceKm: distanceKm,
      warehouseName: warehouseName,
      warehouseAddress: warehouseAddress,
      warehouseLat: warehouseLat,
      warehouseLng: warehouseLng,
      verificationCode: verificationCode ?? this.verificationCode,
      deliveryNote: deliveryNote,
    );
  }

  static String _resolveSellerName(CachedOrderModel cached) {
    if (cached.warehouseAddress != null && cached.warehouseAddress!.isNotEmpty) {
      final parts = cached.warehouseAddress!.split(',');
      if (parts.isNotEmpty) {
        final candidate = parts.first.trim();
        if (candidate.isNotEmpty && !candidate.toLowerCase().startsWith('jl.')) {
          return candidate;
        }
      }
    }

    final pName = cached.productName.toLowerCase();
    if (pName.contains('tepung')) {
      return 'PT Bogasari Flour Mills';
    } else if (pName.contains('susu')) {
      return 'PT Maju Pangan Abadi';
    } else if (pName.contains('minyak')) {
      return 'CV Berkah Nabati';
    } else if (pName.contains('keju')) {
      return 'PT Prima Dairy Food';
    } else if (pName.contains('nugget') || pName.contains('sosis')) {
      return 'PT Charoen Pokphand';
    } else if (pName.contains('sarden')) {
      return 'PT Heinz ABC Indonesia';
    }

    return 'PT Sumber Pangan Abadi';
  }

  /// Konversi dari CachedOrderModel SQLite
  factory TransactionOrder.fromCachedOrder(CachedOrderModel cached) {
    return TransactionOrder(
      id: cached.id,
      orderCode: '#ORD-RCV-${cached.id}',
      listingId: cached.listingId,
      productName: cached.productName.isNotEmpty ? cached.productName : 'Lot Pangan B2B',
      category: cached.category,
      batchNumber: cached.batchNumber.isNotEmpty ? cached.batchNumber : 'RCV-LOT-${cached.id}',
      imageUrl: '',
      qty: cached.qty,
      unit: 'Box',
      unitPrice: cached.finalUnitPrice,
      totalPrice: cached.totalPrice,
      status: cached.status,
      createdAt: DateTime.tryParse(cached.createdAt) ?? DateTime.now(),
      pickupDeadline: DateTime.now().add(const Duration(hours: 24)),
      partnerName: _resolveSellerName(cached),
      warehouseAddress: cached.warehouseAddress,
      warehouseLat: cached.warehouseLat,
      warehouseLng: cached.warehouseLng,
    );
  }

  /// Konversi kembali ke CachedOrderModel untuk persistensi SQLite
  CachedOrderModel toCachedOrder({int buyerId = 1}) {
    return CachedOrderModel(
      id: id,
      listingId: listingId,
      buyerId: buyerId,
      qty: qty,
      finalUnitPrice: unitPrice,
      totalPrice: totalPrice,
      status: status,
      createdAt: createdAt.toIso8601String(),
      productName: productName,
      category: category,
      batchNumber: batchNumber,
      warehouseLat: warehouseLat,
      warehouseLng: warehouseLng,
      warehouseAddress: warehouseAddress,
      cachedAt: DateTime.now().toIso8601String(),
    );
  }
}
