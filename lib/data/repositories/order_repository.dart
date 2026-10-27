import '../../core/services/network_connectivity_service.dart';
import '../models/cached_order_model.dart';
import '../services/local_database_service.dart';

/// Contract for remote order client.
abstract class RemoteOrderClient {
  Future<List<CachedOrderModel>> fetchRemoteOrders();
  Future<CachedOrderModel> fetchRemoteOrderDetail(int orderId);
  Future<CachedOrderModel>? buyListing(
    int listingId, {
    int qty = 1,
    bool biometricVerified = true,
  }) => null;
  Future<CachedOrderModel>? updateOrderStatus(int orderId, String status) =>
      null;
  Future<void>? remindSeller(int orderId) => null;
}

/// Repository for orders, providing offline caching and coordinates for compass navigation.
class OrderRepository {
  final LocalDatabaseService _localDb;
  final RemoteOrderClient? remoteClient;

  OrderRepository({LocalDatabaseService? localDb, this.remoteClient})
    : _localDb = localDb ?? LocalDatabaseService();

  /// Buy a listing via backend API and cache the resulting order.
  Future<CachedOrderModel> buyListing(
    int listingId, {
    int qty = 1,
    bool biometricVerified = true,
  }) async {
    final client = remoteClient;
    if (client == null) {
      throw StateError('Cannot buy listing: No RemoteOrderClient configured.');
    }
    final order = await client.buyListing(
      listingId,
      qty: qty,
      biometricVerified: biometricVerified,
    );
    if (order != null) {
      await _localDb.upsertOrder(order);
      return order;
    }
    throw StateError('Failed to complete purchase.');
  }

  /// Fetch orders, refreshing from network if online, falling back to SQLite `cached_orders`.
  Future<List<CachedOrderModel>> getOrders({
    bool forceRefresh = false,
    int? buyerId,
    String? status,
  }) async {
    final client = remoteClient;
    final isOnline = NetworkConnectivityService.instance.isOnline;

    if (!isOnline) {
      return await _localDb.getOrders(buyerId: buyerId, status: status);
    }

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

  Future<CachedOrderModel> updateOrderStatus(int orderId, String status) async {
    final client = remoteClient;
    if (client == null) throw StateError('No remote order client configured.');
    final order = await client.updateOrderStatus(orderId, status);
    if (order == null) throw StateError('Failed to update order status.');
    await _localDb.upsertOrder(order);
    return order;
  }

  Future<void> remindSeller(int orderId) async {
    final client = remoteClient;
    if (client == null) throw StateError('No remote order client configured.');
    await client.remindSeller(orderId);
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
