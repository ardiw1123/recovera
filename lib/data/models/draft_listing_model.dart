import '../database/database_constants.dart';

/// Data model representing a draft listing in SQLite table `draft_listings`.
/// Includes offline sync queue state (pending / synced / failed) per US-12 and US-03.
class DraftListingModel {
  final int? id;
  final int? productId;
  final String productName;
  final String? brand;
  final String category;
  final String storageType;
  final String defaultUnit;
  final String batchNumber;
  final int qty;
  final double normalPrice;
  final double? startPrice;
  final double minPrice;
  final int dropIntervalMinutes;
  final double dropPercentage;
  final String expiryDate;
  final String? auctionStartAt;
  final String? auctionEndAt;
  final String? localImagePath;
  final String syncStatus;
  final int? serverListingId;
  final String? syncError;
  final String createdAt;
  final String updatedAt;

  const DraftListingModel({
    this.id,
    this.productId,
    required this.productName,
    this.brand,
    required this.category,
    this.storageType = 'ambient',
    this.defaultUnit = 'pcs',
    required this.batchNumber,
    required this.qty,
    required this.normalPrice,
    this.startPrice,
    required this.minPrice,
    this.dropIntervalMinutes = 60,
    this.dropPercentage = 2.50,
    required this.expiryDate,
    this.auctionStartAt,
    this.auctionEndAt,
    this.localImagePath,
    this.syncStatus = DatabaseConstants.syncStatusPending,
    this.serverListingId,
    this.syncError,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => syncStatus == DatabaseConstants.syncStatusPending;
  bool get isSynced => syncStatus == DatabaseConstants.syncStatusSynced;
  bool get isFailed => syncStatus == DatabaseConstants.syncStatusFailed;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      DatabaseConstants.colDraftProductId: productId,
      DatabaseConstants.colDraftProductName: productName,
      DatabaseConstants.colDraftBrand: brand,
      DatabaseConstants.colDraftCategory: category,
      DatabaseConstants.colDraftStorageType: storageType,
      DatabaseConstants.colDraftDefaultUnit: defaultUnit,
      DatabaseConstants.colDraftBatchNumber: batchNumber,
      DatabaseConstants.colDraftQty: qty,
      DatabaseConstants.colDraftNormalPrice: normalPrice,
      DatabaseConstants.colDraftStartPrice: startPrice,
      DatabaseConstants.colDraftMinPrice: minPrice,
      DatabaseConstants.colDraftDropIntervalMinutes: dropIntervalMinutes,
      DatabaseConstants.colDraftDropPercentage: dropPercentage,
      DatabaseConstants.colDraftExpiryDate: expiryDate,
      DatabaseConstants.colDraftAuctionStartAt: auctionStartAt,
      DatabaseConstants.colDraftAuctionEndAt: auctionEndAt,
      DatabaseConstants.colDraftLocalImagePath: localImagePath,
      DatabaseConstants.colDraftSyncStatus: syncStatus,
      DatabaseConstants.colDraftServerListingId: serverListingId,
      DatabaseConstants.colDraftSyncError: syncError,
      DatabaseConstants.colDraftCreatedAt: createdAt,
      DatabaseConstants.colDraftUpdatedAt: updatedAt,
    };
    if (id != null) {
      map[DatabaseConstants.colDraftId] = id;
    }
    return map;
  }

  factory DraftListingModel.fromMap(Map<String, dynamic> map) {
    return DraftListingModel(
      id: map[DatabaseConstants.colDraftId] as int?,
      productId: map[DatabaseConstants.colDraftProductId] as int?,
      productName: map[DatabaseConstants.colDraftProductName] as String,
      brand: map[DatabaseConstants.colDraftBrand] as String?,
      category: map[DatabaseConstants.colDraftCategory] as String,
      storageType: (map[DatabaseConstants.colDraftStorageType] as String?) ?? 'ambient',
      defaultUnit: (map[DatabaseConstants.colDraftDefaultUnit] as String?) ?? 'pcs',
      batchNumber: map[DatabaseConstants.colDraftBatchNumber] as String,
      qty: map[DatabaseConstants.colDraftQty] as int,
      normalPrice: (map[DatabaseConstants.colDraftNormalPrice] as num).toDouble(),
      startPrice: (map[DatabaseConstants.colDraftStartPrice] as num?)?.toDouble(),
      minPrice: (map[DatabaseConstants.colDraftMinPrice] as num).toDouble(),
      dropIntervalMinutes: (map[DatabaseConstants.colDraftDropIntervalMinutes] as int?) ?? 60,
      dropPercentage: ((map[DatabaseConstants.colDraftDropPercentage] as num?) ?? 2.50).toDouble(),
      expiryDate: map[DatabaseConstants.colDraftExpiryDate] as String,
      auctionStartAt: map[DatabaseConstants.colDraftAuctionStartAt] as String?,
      auctionEndAt: map[DatabaseConstants.colDraftAuctionEndAt] as String?,
      localImagePath: map[DatabaseConstants.colDraftLocalImagePath] as String?,
      syncStatus: (map[DatabaseConstants.colDraftSyncStatus] as String?) ?? DatabaseConstants.syncStatusPending,
      serverListingId: map[DatabaseConstants.colDraftServerListingId] as int?,
      syncError: map[DatabaseConstants.colDraftSyncError] as String?,
      createdAt: map[DatabaseConstants.colDraftCreatedAt] as String,
      updatedAt: map[DatabaseConstants.colDraftUpdatedAt] as String,
    );
  }

  /// Create a new draft instance ready for local persistence
  factory DraftListingModel.create({
    int? productId,
    required String productName,
    String? brand,
    required String category,
    String storageType = 'ambient',
    String defaultUnit = 'pcs',
    required String batchNumber,
    required int qty,
    required double normalPrice,
    double? startPrice,
    required double minPrice,
    int dropIntervalMinutes = 60,
    double dropPercentage = 2.50,
    required String expiryDate,
    String? auctionStartAt,
    String? auctionEndAt,
    String? localImagePath,
  }) {
    final now = DateTime.now().toIso8601String();
    return DraftListingModel(
      productId: productId,
      productName: productName,
      brand: brand,
      category: category,
      storageType: storageType,
      defaultUnit: defaultUnit,
      batchNumber: batchNumber,
      qty: qty,
      normalPrice: normalPrice,
      startPrice: startPrice,
      minPrice: minPrice,
      dropIntervalMinutes: dropIntervalMinutes,
      dropPercentage: dropPercentage,
      expiryDate: expiryDate,
      auctionStartAt: auctionStartAt,
      auctionEndAt: auctionEndAt,
      localImagePath: localImagePath,
      syncStatus: DatabaseConstants.syncStatusPending,
      createdAt: now,
      updatedAt: now,
    );
  }

  DraftListingModel copyWith({
    int? id,
    int? productId,
    String? productName,
    String? brand,
    String? category,
    String storageType = 'ambient',
    String defaultUnit = 'pcs',
    String? batchNumber,
    int? qty,
    double? normalPrice,
    double? startPrice,
    double? minPrice,
    int? dropIntervalMinutes,
    double? dropPercentage,
    String? expiryDate,
    String? auctionStartAt,
    String? auctionEndAt,
    String? localImagePath,
    String? syncStatus,
    int? serverListingId,
    String? syncError,
    String? createdAt,
    String? updatedAt,
  }) {
    return DraftListingModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      storageType: storageType,
      defaultUnit: defaultUnit,
      batchNumber: batchNumber ?? this.batchNumber,
      qty: qty ?? this.qty,
      normalPrice: normalPrice ?? this.normalPrice,
      startPrice: startPrice ?? this.startPrice,
      minPrice: minPrice ?? this.minPrice,
      dropIntervalMinutes: dropIntervalMinutes ?? this.dropIntervalMinutes,
      dropPercentage: dropPercentage ?? this.dropPercentage,
      expiryDate: expiryDate ?? this.expiryDate,
      auctionStartAt: auctionStartAt ?? this.auctionStartAt,
      auctionEndAt: auctionEndAt ?? this.auctionEndAt,
      localImagePath: localImagePath ?? this.localImagePath,
      syncStatus: syncStatus ?? this.syncStatus,
      serverListingId: serverListingId ?? this.serverListingId,
      syncError: syncError ?? this.syncError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
