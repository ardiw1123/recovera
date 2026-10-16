import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/cached_listing_model.dart';
import '../models/draft_listing_model.dart';
import '../repositories/listing_repository.dart';

/// Implementasi RemoteListingClient yang terhubung langsung dengan backend FastAPI Recovera
class ListingApiService implements RemoteListingClient {
  ListingApiService({required this.client});

  final ApiClient client;

  @override
  Future<List<CachedListingModel>> fetchRemoteListings({
    String? search,
    String? category,
    double? maxPrice,
    int? minDays,
    String? sort,
  }) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      queryParams['category'] = category.trim();
    }
    if (maxPrice != null && maxPrice > 0) {
      queryParams['max_price'] = maxPrice;
    }
    if (minDays != null && minDays > 0) {
      queryParams['min_days'] = minDays;
    }
    if (sort != null && sort.trim().isNotEmpty) {
      queryParams['sort'] = sort.trim();
    }

    try {
      final response = await client.get<Map<String, dynamic>>(
        '/listings',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal memuat katalog lelang';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      final items = body['data'] as List<dynamic>? ?? [];
      return items
          .map((item) =>
              CachedListingModel.fromApiResponse(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memuat katalog lelang');
    }
  }

  @override
  Future<int> uploadDraftListing(DraftListingModel draft) async {
    final payload = <String, dynamic>{
      'product_id': draft.productId ?? 1,
      'batch_number': draft.batchNumber,
      'qty': draft.qty,
      'normal_price': draft.normalPrice,
      'min_price': draft.minPrice,
      'drop_interval_minutes': draft.dropIntervalMinutes,
      'drop_percentage': draft.dropPercentage,
      'expiry_date': draft.expiryDate,
    };
    if (draft.startPrice != null) {
      payload['start_price'] = draft.startPrice;
    }
    if (draft.auctionStartAt != null) {
      payload['auction_start_at'] = draft.auctionStartAt;
    }
    if (draft.auctionEndAt != null) {
      payload['auction_end_at'] = draft.auctionEndAt;
    }

    try {
      final response = await client.post<Map<String, dynamic>>(
        '/listings',
        data: payload,
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error = body?['error']?['message'] ?? 'Gagal membuat listing';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      final data = body['data'] as Map<String, dynamic>;
      return data['id'] as int;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal mengunggah draf lelang');
    }
  }
}
