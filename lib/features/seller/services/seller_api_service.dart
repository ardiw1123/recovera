import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/seller_inventory_model.dart';

/// Service API khusus untuk alur kerja penjual (Seller Inventory & Upload Journey).
class SellerApiService {
  SellerApiService({required this.client});

  final ApiClient client;

  /// Mengambil daftar inventaris produk lelang milik penjual yang sedang login.
  /// Menghubungi endpoint GET /listings/seller/inventory
  Future<List<SellerListingItem>> fetchSellerInventory() async {
    try {
      final response = await client.get<Map<String, dynamic>>(
        '/listings/seller/inventory',
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal memuat inventaris penjual';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      final items = body['data'] as List<dynamic>? ?? [];
      return items
          .map((item) =>
              SellerListingItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memuat inventaris penjual');
    }
  }

  /// Membuat draf produk dan listing baru dengan validasi otomatis & saran harga awal.
  /// Menghubungi endpoint POST /listings/seller/inventory/drafts
  Future<Map<String, dynamic>> createDraft(
      SellerDraftCreatePayload payload) async {
    try {
      final response = await client.post<Map<String, dynamic>>(
        '/listings/seller/inventory/drafts',
        data: payload.toJson(),
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error = body?['error']?['message'] ?? 'Gagal membuat draf produk';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      final data = body['data'] as Map<String, dynamic>;
      final listingMap = data['listing'] as Map<String, dynamic>;
      final listing = SellerListingItem.fromJson(listingMap);
      final validation = SellerValidationResult.fromJson(
          data['validation'] as Map<String, dynamic>? ?? {});
      final recommendation = SellerRecommendationResult.fromJson(
          data['price_recommendation'] as Map<String, dynamic>? ?? {});

      return {
        'listing': listing,
        'validation': validation,
        'recommendation': recommendation,
      };
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal membuat draf produk');
    }
  }

  /// Memperbarui informasi draf produk atau harga.
  /// Menghubungi endpoint PATCH /listings/seller/inventory/{listing_id}
  Future<Map<String, dynamic>> updateDraft(
    int listingId,
    Map<String, dynamic> patch,
  ) async {
    try {
      final response = await client.patch<Map<String, dynamic>>(
        '/listings/seller/inventory/$listingId',
        data: patch,
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal memperbarui draf produk';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      final data = body['data'] as Map<String, dynamic>;
      final listingMap = data['listing'] as Map<String, dynamic>;
      final listing = SellerListingItem.fromJson(listingMap);
      final validation = SellerValidationResult.fromJson(
          data['validation'] as Map<String, dynamic>? ?? {});

      return {
        'listing': listing,
        'validation': validation,
      };
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memperbarui draf produk');
    }
  }

  /// Menjalankan validasi standar pangan sistem Recovera terhadap draf produk.
  /// Menghubungi endpoint POST /listings/seller/inventory/{listing_id}/validate
  Future<SellerValidationResult> validateDraft(int listingId) async {
    try {
      final response = await client.post<Map<String, dynamic>>(
        '/listings/seller/inventory/$listingId/validate',
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal memvalidasi standar mutu';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      final data = body['data'] as Map<String, dynamic>;
      return SellerValidationResult.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memvalidasi standar mutu');
    }
  }

  /// Meminta rekomendasi harga AI dan batas rentang yang diperbolehkan.
  /// Menghubungi endpoint POST /listings/seller/inventory/{listing_id}/recommendation
  Future<SellerRecommendationResult> getPriceRecommendation(
      int listingId) async {
    try {
      final response = await client.post<Map<String, dynamic>>(
        '/listings/seller/inventory/$listingId/recommendation',
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal memuat rekomendasi harga';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      final data = body['data'] as Map<String, dynamic>;
      return SellerRecommendationResult.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memuat rekomendasi harga');
    }
  }

  /// Mempublikasikan draf produk ke katalog lelang aktif aplikasi.
  /// Menghubungi endpoint POST /listings/seller/inventory/{listing_id}/publish
  Future<SellerListingItem> publishListing(
    int listingId, {
    bool acknowledgePriceWarning = false,
  }) async {
    try {
      final response = await client.post<Map<String, dynamic>>(
        '/listings/seller/inventory/$listingId/publish',
        data: {'acknowledge_price_warning': acknowledgePriceWarning},
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal mempublikasikan produk lelang';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      final data = body['data'] as Map<String, dynamic>;
      return SellerListingItem.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final error = e.response?.data?['error']?['message'] ??
            'Peringatan deviasi harga memerlukan konfirmasi untuk melanjutkan.';
        throw ApiException(error, code: 'PRICE_WARNING_ACK_REQUIRED');
      }
      throw ApiException.fromDioException(
          e, 'Gagal mempublikasikan produk lelang');
    }
  }
}
