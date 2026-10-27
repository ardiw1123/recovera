import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/esg_certificate_model.dart';
import '../models/seller_dashboard_model.dart';
import '../models/seller_inventory_model.dart';

/// Service API khusus untuk alur kerja penjual (Seller Inventory & Upload Journey).
class SellerApiService {
  SellerApiService({required this.client});

  final ApiClient client;

  Future<String> uploadProductImage({
    required String filePath,
    Uint8List? bytes,
    String? filename,
  }) async {
    try {
      final multipart = bytes != null && bytes.isNotEmpty
          ? MultipartFile.fromBytes(bytes, filename: filename ?? 'product.jpg')
          : await MultipartFile.fromFile(
              filePath,
              filename: filename ?? filePath.split(RegExp(r'[/\\]')).last,
            );
      final response = await client.post<Map<String, dynamic>>(
        '/products/upload-image',
        data: FormData.fromMap({'file': multipart}),
      );
      final body = response.data;
      if (body == null || body['success'] != true) {
        throw ApiException(
          body?['error']?['message'] ?? 'Foto produk gagal diunggah',
        );
      }
      return (body['data'] as Map<String, dynamic>)['image_url'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Foto produk gagal diunggah');
    }
  }

  /// Mengambil data dashboard lengkap untuk halaman beranda seller.
  /// Menghubungi endpoint GET /listings/seller/dashboard
  Future<SellerDashboardData> fetchDashboard() async {
    try {
      final response = await client.get<Map<String, dynamic>>(
        '/listings/seller/dashboard',
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal memuat dashboard penjual';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      final data = body['data'] as Map<String, dynamic>;
      return SellerDashboardData.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memuat dashboard penjual');
    }
  }

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
          .map(
            (item) => SellerListingItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memuat inventaris penjual');
    }
  }

  /// Membuat draf produk dan listing baru dengan validasi otomatis & saran harga awal.
  /// Menghubungi endpoint POST /listings/seller/inventory/drafts
  Future<Map<String, dynamic>> createDraft(
    SellerDraftCreatePayload payload,
  ) async {
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
        data['validation'] as Map<String, dynamic>? ?? {},
      );
      final recommendation = SellerRecommendationResult.fromJson(
        data['price_recommendation'] as Map<String, dynamic>? ?? {},
      );

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
        data['validation'] as Map<String, dynamic>? ?? {},
      );

      return {'listing': listing, 'validation': validation};
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
    int listingId,
  ) async {
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
        final error =
            e.response?.data?['error']?['message'] ??
            'Peringatan deviasi harga memerlukan konfirmasi untuk melanjutkan.';
        throw ApiException(error, code: 'PRICE_WARNING_ACK_REQUIRED');
      }
      throw ApiException.fromDioException(
        e,
        'Gagal mempublikasikan produk lelang',
      );
    }
  }

  /// Mengirim foto faktur/produk ke endpoint POST /ai/invoice untuk ekstraksi OCR Gemini.
  Future<Map<String, dynamic>> uploadInvoiceForOcr({
    required String filePath,
    Uint8List? bytes,
    String? filename,
  }) async {
    try {
      MultipartFile multipartFile;
      if (bytes != null && bytes.isNotEmpty) {
        multipartFile = MultipartFile.fromBytes(
          bytes,
          filename: filename ?? 'invoice.jpg',
        );
      } else if (filePath.isNotEmpty &&
          (filePath.startsWith('http://') || filePath.startsWith('https://'))) {
        multipartFile = MultipartFile.fromBytes(
          Uint8List.fromList([0, 1, 2, 3]),
          filename: filename ?? 'invoice.jpg',
        );
      } else if (filePath.isNotEmpty) {
        try {
          multipartFile = await MultipartFile.fromFile(
            filePath,
            filename: filename ?? filePath.split('/').last.split('\\').last,
          );
        } catch (_) {
          multipartFile = MultipartFile.fromBytes(
            Uint8List.fromList([0, 1, 2, 3]),
            filename: filename ?? 'invoice.jpg',
          );
        }
      } else {
        multipartFile = MultipartFile.fromBytes(
          Uint8List.fromList([0, 1, 2, 3]),
          filename: filename ?? 'invoice.jpg',
        );
      }

      final formData = FormData.fromMap({'file': multipartFile});

      final response = await client.post<Map<String, dynamic>>(
        '/ai/invoice',
        data: formData,
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal memindai faktur dengan OCR AI';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      return body['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(
        e,
        'Gagal memindai faktur dengan OCR AI',
      );
    }
  }

  /// Menghapus draf produk lelang dari sistem.
  /// Menghubungi endpoint DELETE /listings/seller/inventory/{listing_id}
  Future<void> deleteDraft(int listingId) async {
    try {
      final response = await client.delete<Map<String, dynamic>>(
        '/listings/seller/inventory/$listingId',
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal menghapus draf produk';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal menghapus draf produk');
    }
  }

  /// Mengambil daftar sertifikat donasi / ESG milik seller.
  Future<List<EsgCertificateListItem>> fetchMyCertificates() async {
    try {
      final response = await client.get<Map<String, dynamic>>('/donations/my');
      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal memuat sertifikat ESG';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map(
            (item) =>
                EsgCertificateListItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memuat sertifikat ESG');
    }
  }

  Future<List<EsgCertificateListItem>> fetchSellerCertificates(
    int sellerId,
  ) async {
    try {
      final response = await client.get<Map<String, dynamic>>(
        '/donations/sellers/$sellerId/certificates',
      );
      final body = response.data;
      if (body == null || body['success'] != true) {
        throw ApiException(
          body?['error']?['message'] ?? 'Gagal memuat sertifikat penjual',
        );
      }
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map(
            (item) =>
                EsgCertificateListItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memuat sertifikat penjual');
    }
  }

  /// Mengambil detail satu sertifikat donasi / ESG.
  Future<EsgCertificateDetail> fetchCertificateDetail(int donationId) async {
    try {
      final response = await client.get<Map<String, dynamic>>(
        '/donations/$donationId/certificate',
      );
      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ?? 'Gagal memuat detail sertifikat';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }
      final data = body['data'] as Map<String, dynamic>;
      return EsgCertificateDetail.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memuat detail sertifikat');
    }
  }

  /// Memverifikasi hash transaksi sertifikat secara on-chain ke BOT Chain Testnet.
  Future<BlockchainVerificationResult> verifyBlockchain(String txHash) async {
    try {
      final response = await client.get<Map<String, dynamic>>(
        '/blockchain/verify/$txHash',
      );
      final body = response.data;
      if (body == null || body['success'] != true) {
        final error =
            body?['error']?['message'] ??
            'Gagal memverifikasi transaksi blockchain';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }
      final data = body['data'] as Map<String, dynamic>;
      return BlockchainVerificationResult.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(
        e,
        'Gagal memverifikasi transaksi blockchain',
      );
    }
  }
}
