import 'package:dio/dio.dart';

/// Representasi exception terstruktur untuk respon error dari API backend Recovera.
/// Memastikan kode error (seperti MISSING_SELLER_INFO, EMAIL_ALREADY_EXISTS,
/// VALIDATION_ERROR) dan pesan spesifik dari backend dapat diproses serta
/// ditampilkan secara transparan di UI.
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic details;

  const ApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.details,
  });

  /// Ekstraksi error dari DioException dengan membaca envelope standar backend:
  /// `{ "success": false, "error": { "code": "...", "message": "..." } }`
  factory ApiException.fromDioException(
    DioException e, [
    String defaultMessage = 'Terjadi kesalahan pada server',
  ]) {
    final response = e.response;
    final statusCode = response?.statusCode;
    final data = response?.data;

    String message = defaultMessage;
    String? code;

    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        code = error['code'] as String?;
        final msg = error['message'];
        if (msg != null && msg.toString().trim().isNotEmpty) {
          message = msg.toString();
        }
      } else if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
        message = data['message'].toString();
      } else if (data['detail'] != null) {
        final detail = data['detail'];
        if (detail is List) {
          message = detail.map((d) {
            if (d is Map && d['msg'] != null) {
              final loc = (d['loc'] as List?)?.join(' -> ') ?? '';
              return loc.isNotEmpty ? '$loc: ${d['msg']}' : d['msg'].toString();
            }
            return d.toString();
          }).join('; ');
        } else {
          message = detail.toString();
        }
      }
    } else if (e.message != null && e.message!.isNotEmpty) {
      message = e.message!;
    }

    return ApiException(
      message,
      code: code,
      statusCode: statusCode,
      details: data,
    );
  }

  @override
  String toString() => message;
}
