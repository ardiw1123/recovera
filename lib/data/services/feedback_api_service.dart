import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

/// Service untuk mengirim Saran & Kesan ke backend Recovera via POST /feedback
class FeedbackApiService {
  FeedbackApiService({required this.client});

  final ApiClient client;

  Future<Map<String, dynamic>> submitFeedback({
    required String kesan,
    required String saran,
  }) async {
    try {
      final response = await client.post<Map<String, dynamic>>(
        '/feedback',
        data: {
          'kesan': kesan,
          'saran': saran,
        },
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final error = body?['error']?['message'] ?? 'Gagal mengirim saran';
        final code = body?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      return body['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal mengirim saran & kesan');
    }
  }
}
