import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/cached_order_model.dart';
import '../repositories/order_repository.dart';

/// Implementasi RemoteOrderClient yang terhubung langsung dengan backend FastAPI Recovera
class OrderApiService implements RemoteOrderClient {
  OrderApiService({required this.client});

  final ApiClient client;

  @override
  Future<List<CachedOrderModel>> fetchRemoteOrders() async {
    try {
      final response = await client.get<Map<String, dynamic>>('/orders');

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error = body?['error']?['message'] ?? 'Gagal memuat pesanan';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      final items = body['data'] as List<dynamic>? ?? [];
      return items
          .map((item) =>
              CachedOrderModel.fromApiResponse(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memuat riwayat pesanan');
    }
  }

  @override
  Future<CachedOrderModel> fetchRemoteOrderDetail(int orderId) async {
    try {
      final response =
          await client.get<Map<String, dynamic>>('/orders/$orderId');

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal memuat detail pesanan';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      return CachedOrderModel.fromApiResponse(
          body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memuat detail pesanan');
    }
  }

  @override
  Future<CachedOrderModel> buyListing(
    int listingId, {
    int qty = 1,
    bool biometricVerified = true,
  }) async {
    try {
      final response = await client.post<Map<String, dynamic>>(
        '/listings/$listingId/buy',
        data: {
          'qty': qty,
          'biometric_verified': biometricVerified,
        },
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error = body?['error']?['message'] ?? 'Gagal membeli produk';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      return CachedOrderModel.fromApiResponse(
          body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memproses pembelian');
    }
  }
}
