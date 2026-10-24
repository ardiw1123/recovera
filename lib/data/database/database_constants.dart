/// Database table and column constants for Recovera SQLite local database.
/// Aligned with PRD US-12 and docs/recovera-database-schema.md.
class DatabaseConstants {
  DatabaseConstants._();

  static const String databaseName = 'recovera.db';
  static const int databaseVersion = 1;

  // Table names
  static const String tableCachedListings = 'cached_listings';
  static const String tableDraftListings = 'draft_listings';
  static const String tableCachedOrders = 'cached_orders';
  static const String tableGameScores = 'game_scores';
  static const String tableAppPrefs = 'app_prefs';

  // Columns: cached_listings
  static const String colListingId = 'id';
  static const String colListingProductId = 'product_id';
  static const String colListingSellerId = 'seller_id';
  static const String colListingBatchNumber = 'batch_number';
  static const String colListingQty = 'qty';
  static const String colListingNormalPrice = 'normal_price';
  static const String colListingStartPrice = 'start_price';
  static const String colListingMinPrice = 'min_price';
  static const String colListingCurrentPrice = 'current_price';
  static const String colListingDropIntervalMinutes = 'drop_interval_minutes';
  static const String colListingDropPercentage = 'drop_percentage';
  static const String colListingExpiryDate = 'expiry_date';
  static const String colListingAuctionStartAt = 'auction_start_at';
  static const String colListingAuctionEndAt = 'auction_end_at';
  static const String colListingStatus = 'status';
  static const String colListingCreatedAt = 'created_at';
  static const String colListingProductName = 'product_name';
  static const String colListingBrand = 'brand';
  static const String colListingCategory = 'category';
  static const String colListingStorageType = 'storage_type';
  static const String colListingDefaultUnit = 'default_unit';
  static const String colListingImageUrl = 'image_url';
  static const String colListingSellerCompany = 'seller_company';
  static const String colListingWarehouseLat = 'warehouse_lat';
  static const String colListingWarehouseLng = 'warehouse_lng';
  static const String colListingWarehouseCity = 'warehouse_city';
  static const String colListingDistanceKm = 'distance_km';
  static const String colListingCachedAt = 'cached_at';

  // Columns: draft_listings
  static const String colDraftId = 'id';
  static const String colDraftProductId = 'product_id';
  static const String colDraftProductName = 'product_name';
  static const String colDraftBrand = 'brand';
  static const String colDraftCategory = 'category';
  static const String colDraftStorageType = 'storage_type';
  static const String colDraftDefaultUnit = 'default_unit';
  static const String colDraftBatchNumber = 'batch_number';
  static const String colDraftQty = 'qty';
  static const String colDraftNormalPrice = 'normal_price';
  static const String colDraftStartPrice = 'start_price';
  static const String colDraftMinPrice = 'min_price';
  static const String colDraftDropIntervalMinutes = 'drop_interval_minutes';
  static const String colDraftDropPercentage = 'drop_percentage';
  static const String colDraftExpiryDate = 'expiry_date';
  static const String colDraftAuctionStartAt = 'auction_start_at';
  static const String colDraftAuctionEndAt = 'auction_end_at';
  static const String colDraftLocalImagePath = 'local_image_path';
  static const String colDraftSyncStatus = 'sync_status';
  static const String colDraftServerListingId = 'server_listing_id';
  static const String colDraftSyncError = 'sync_error';
  static const String colDraftCreatedAt = 'created_at';
  static const String colDraftUpdatedAt = 'updated_at';

  // Sync statuses for draft_listings
  static const String syncStatusPending = 'pending';
  static const String syncStatusSynced = 'synced';
  static const String syncStatusFailed = 'failed';

  // Columns: cached_orders
  static const String colOrderId = 'id';
  static const String colOrderListingId = 'listing_id';
  static const String colOrderBuyerId = 'buyer_id';
  static const String colOrderQty = 'qty';
  static const String colOrderFinalUnitPrice = 'final_unit_price';
  static const String colOrderTotalPrice = 'total_price';
  static const String colOrderStatus = 'status';
  static const String colOrderCreatedAt = 'created_at';
  static const String colOrderProductName = 'product_name';
  static const String colOrderCategory = 'category';
  static const String colOrderBatchNumber = 'batch_number';
  static const String colOrderWarehouseLat = 'warehouse_lat';
  static const String colOrderWarehouseLng = 'warehouse_lng';
  static const String colOrderWarehouseAddress = 'warehouse_address';
  static const String colOrderCachedAt = 'cached_at';

  // Columns: game_scores
  static const String colGameId = 'id';
  static const String colGameScore = 'score';
  static const String colGameItemsSaved = 'items_saved';
  static const String colGameBadge = 'badge';
  static const String colGamePlayedAt = 'played_at';

  // Columns: app_prefs
  static const String colPrefKey = 'key';
  static const String colPrefValue = 'value';
  static const String colPrefUpdatedAt = 'updated_at';

  // Standard preference keys
  static const String prefBiometricEnabled = 'biometric_enabled';
  static const String prefSelectedTimezone = 'selected_timezone';
  static const String prefLastCurrencyRates = 'last_currency_rates';
  static const String prefSelectedCurrency = 'selected_currency';
}
