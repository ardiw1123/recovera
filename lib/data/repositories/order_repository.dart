import '../models/cached_order_model.dart';
import '../services/local_database_service.dart';

/// Contract for remote order client.
abstract class RemoteOrderClient {
  Future<List<CachedOrderModel>> fetchRemoteOrders();
  Future<CachedOrderModel> fetchRemoteOrderDetail(int orderId);
}

/// Repository for orders, providing offline caching and coordinates for compass navigation.
class OrderRepository {
  final LocalDatabaseService _localDb;
  final RemoteOrderClient? remoteClient;

  OrderRepository({
    LocalDatabaseService? localDb,
    this.remoteClient,
  }) : _localDb = localDb ?? LocalDatabaseService();

  /// Fetch orders, refreshing from network if online, falling back to SQLite `cached_orders`.
  Future<List<CachedOrderModel>> getOrders({
    bool forceRefresh = false,
    int? buyerId,
    String? status,
  }) async {
    final client = remoteClient;
    if (client != null && forceRefresh) {
      try {
        final remoteOrders = await client.fetchRemoteOrders();
        await _localDb.upsertOrders(remoteOrders);
        return remoteOrders;
      } catch (_) {
        // Fallback to SQLite cache on network error
        return await _localDb.getOrders(buyerId: buyerId, status: status);
      }
    }

    final cached = await _localDb.getOrders(buyerId: buyerId, status: status);
    if (cached.isEmpty && client != null) {
      try {
        final remoteOrders = await client.fetchRemoteOrders();
        await _localDb.upsertOrders(remoteOrders);
        return remoteOrders;
      } catch (_) {
        return const [];
      }
    }

    return cached;
  }

  /// Get specific cached order by ID.
  Future<CachedOrderModel?> getOrderById(int id) async {
    return await _localDb.getOrderById(id);
  }

  /// Cache a single order into SQLite.
  Future<void> cacheOrder(CachedOrderModel order) async {
    await _localDb.upsertOrder(order);
  }

  /// Bulk cache orders into SQLite.
  Future<void> cacheOrders(List<CachedOrderModel> orders) async {
    await _localDb.upsertOrders(orders);
  }

  /// Clear all cached orders.
  Future<void> clearOrderCache() async {
    await _localDb.clearOrders();
  }
}
