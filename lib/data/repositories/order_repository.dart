import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/services/network_connectivity_service.dart';
import '../models/cached_order_model.dart';
import '../services/local_database_service.dart';
import '../services/order_api_service.dart';

/// Contract for remote order client.
abstract class RemoteOrderClient {
  Future<List<CachedOrderModel>> fetchRemoteOrders();
  Future<CachedOrderModel> fetchRemoteOrderDetail(int orderId);
  Future<CachedOrderModel>? buyListing(
    int listingId, {
    int qty = 1,
    bool biometricVerified = true,
  }) => null;
}

/// Repository for orders, providing offline caching and coordinates for compass navigation.
class OrderRepository {
  final LocalDatabaseService _localDb;
  final RemoteOrderClient? remoteClient;

  // In-memory persistent order storage so purchases are never lost across screens
  static final List<CachedOrderModel> _inMemoryOrders = [];

  OrderRepository({
    LocalDatabaseService? localDb,
    RemoteOrderClient? remoteClient,
  })  : _localDb = localDb ?? LocalDatabaseService(),
        remoteClient = remoteClient ?? OrderApiService(client: ApiClient());

  /// Buy a listing via backend API and cache the resulting order.
  Future<CachedOrderModel> buyListing(
    int listingId, {
    int qty = 1,
    bool biometricVerified = true,
  }) async {
    final client = remoteClient;
    if (client != null) {
      try {
        final order = await client.buyListing(
          listingId,
          qty: qty,
          biometricVerified: biometricVerified,
        );
        if (order != null) {
          await cacheOrder(order);
          return order;
        }
      } catch (_) {
        // Fallback handled by caller
        rethrow;
      }
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

    if (isOnline && client != null) {
      try {
        final remoteOrders = await client.fetchRemoteOrders();
        for (final ro in remoteOrders) {
          _upsertInMemory(ro);
        }
        if (!kIsWeb) {
          try {
            await _localDb.upsertOrders(remoteOrders);
          } catch (_) {}
        }
      } catch (_) {}
    }

    // Load from local database if not web
    List<CachedOrderModel> dbOrders = [];
    if (!kIsWeb) {
      try {
        dbOrders = await _localDb.getOrders(buyerId: buyerId, status: status);
        for (final dbo in dbOrders) {
          _upsertInMemory(dbo);
        }
      } catch (_) {}
    }

    // Filter in-memory orders
    var result = List<CachedOrderModel>.from(_inMemoryOrders);
    if (buyerId != null) {
      result = result.where((o) => o.buyerId == buyerId).toList();
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      result = result.where((o) => o.status.toLowerCase() == status.toLowerCase()).toList();
    }

    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// Get specific cached order by ID.
  Future<CachedOrderModel?> getOrderById(int id) async {
    final match = _inMemoryOrders.where((o) => o.id == id);
    if (match.isNotEmpty) return match.first;
    if (!kIsWeb) {
      try {
        return await _localDb.getOrderById(id);
      } catch (_) {}
    }
    return null;
  }

  /// Cache a single order into SQLite and in-memory storage.
  Future<void> cacheOrder(CachedOrderModel order) async {
    _upsertInMemory(order);
    if (!kIsWeb) {
      try {
        await _localDb.upsertOrder(order);
      } catch (_) {}
    }
  }

  /// Bulk cache orders into SQLite and in-memory storage.
  Future<void> cacheOrders(List<CachedOrderModel> orders) async {
    for (final order in orders) {
      _upsertInMemory(order);
    }
    if (!kIsWeb) {
      try {
        await _localDb.upsertOrders(orders);
      } catch (_) {}
    }
  }

  /// Clear all cached orders.
  Future<void> clearOrderCache() async {
    _inMemoryOrders.clear();
    if (!kIsWeb) {
      try {
        await _localDb.clearOrders();
      } catch (_) {}
    }
  }

  static void _upsertInMemory(CachedOrderModel order) {
    final idx = _inMemoryOrders.indexWhere((o) => o.id == order.id);
    if (idx != -1) {
      _inMemoryOrders[idx] = order;
    } else {
      _inMemoryOrders.insert(0, order);
    }
  }
}
