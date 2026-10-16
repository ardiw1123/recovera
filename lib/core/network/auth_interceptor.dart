import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

typedef SessionExpiredCallback = void Function(String message);

/// Interceptor Dio untuk:
/// 1. Menyuntikkan Bearer token secara otomatis pada setiap request privat.
/// 2. Menangani HTTP 401 dengan silent refresh terkoordinasi (single-flight retry queue).
/// 3. Menghapus sesi dan memicu navigasi Login saat refresh token kedaluwarsa/tidak sah.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenStorage,
    Dio? refreshDio,
    this.onSessionExpired,
  }) : _refreshDio = refreshDio ?? Dio();

  final ITokenStorage tokenStorage;
  final Dio _refreshDio;
  final SessionExpiredCallback? onSessionExpired;

  /// Completer untuk mengoordinasikan satu pemanggilan refresh secara bersamaan
  /// bagi seluruh request yang mengalami 401, mencegah pemulihan ganda / race conditions.
  Completer<String?>? _refreshCompleter;

  static const String retryExtraKey = '_auth_is_retry';
  static const String noAuthExtraKey = '_no_auth';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. Lewati penambahan header jika endpoint bersifat publik atau eksplisit noAuth
    if (_isPublicPath(options.path) || options.extra[noAuthExtraKey] == true) {
      return handler.next(options);
    }

    // 2. Jika sedang ada proses refresh yang berjalan, tunggu token baru terlebih dahulu
    // agar request ini tidak langsung gagal dengan token lama yang kedaluwarsa.
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      try {
        final newToken = await _refreshCompleter!.future;
        if (newToken != null && newToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $newToken';
          return handler.next(options);
        }
      } catch (_) {
        // Lanjutkan pengambilan token tersimpan jika terjadi error
      }
    }

    // 3. Ambil access token dari penyimpanan aman dan sisipkan ke header Authorization
    final accessToken = await tokenStorage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final statusCode = response?.statusCode;
    final requestOptions = err.requestOptions;

    // Hanya tangani 401 Unauthorized
    if (statusCode != 401) {
      return handler.next(err);
    }

    // A. Jika request yang 401 adalah endpoint refresh itu sendiri,
    // maka refresh token sudah tidak sah atau kedaluwarsa.
    if (requestOptions.path.contains(ApiConstants.refreshEndpoint)) {
      await _handleSessionTermination(response?.data);
      return handler.reject(err);
    }

    // B. Jangan mengulang request yang sudah pernah di-retry untuk mencegah loop tak terbatas
    if (requestOptions.extra[retryExtraKey] == true) {
      return handler.reject(err);
    }

    // C. Koordinasikan silent refresh dan antrean retry transparan
    try {
      final newToken = await _performOrJoinRefresh();

      if (newToken == null || newToken.isEmpty) {
        // Refresh gagal secara permanen / sesi telah berakhir
        return handler.reject(err);
      }

      // Retry request asli secara transparan dengan token baru
      final client = Dio(
        BaseOptions(
          baseUrl: requestOptions.baseUrl,
          connectTimeout: requestOptions.connectTimeout,
          receiveTimeout: requestOptions.receiveTimeout,
          sendTimeout: requestOptions.sendTimeout,
        ),
      );
      if (err.requestOptions.extra.containsKey('_adapter')) {
        client.httpClientAdapter =
            err.requestOptions.extra['_adapter'] as HttpClientAdapter;
      }

      final newHeaders = Map<String, dynamic>.from(requestOptions.headers);
      newHeaders['Authorization'] = 'Bearer $newToken';

      final retryOptions = Options(
        method: requestOptions.method,
        headers: newHeaders,
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        validateStatus: requestOptions.validateStatus,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        followRedirects: requestOptions.followRedirects,
        maxRedirects: requestOptions.maxRedirects,
        requestEncoder: requestOptions.requestEncoder,
        responseDecoder: requestOptions.responseDecoder,
        listFormat: requestOptions.listFormat,
        extra: {
          ...requestOptions.extra,
          retryExtraKey: true,
        },
      );

      final retryResponse = await client.request<dynamic>(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: retryOptions,
      );

      return handler.resolve(retryResponse);
    } catch (e) {
      if (e is DioException) {
        return handler.reject(e);
      }
      return handler.reject(
        DioException(
          requestOptions: requestOptions,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  /// Menjalankan atau bergabung ke proses refresh token yang sedang berjalan.
  Future<String?> _performOrJoinRefresh() async {
    if (_refreshCompleter != null) {
      // Ada request lain yang sudah memulai refresh; tunggu hasilnya
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final currentRefreshToken = await tokenStorage.getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        await _handleSessionTermination(null);
        _refreshCompleter!.complete(null);
        return null;
      }

      // Lakukan panggilan POST /auth/refresh
      final refreshUrl = ApiConstants.refreshEndpoint.startsWith('http')
          ? ApiConstants.refreshEndpoint
          : '${ApiConstants.baseUrl}${ApiConstants.refreshEndpoint}';

      final response = await _refreshDio.post<Map<String, dynamic>>(
        refreshUrl,
        data: {'refresh_token': currentRefreshToken},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          extra: {noAuthExtraKey: true},
        ),
      );

      final responseBody = response.data;
      if (responseBody != null && responseBody['success'] == true) {
        final data = responseBody['data'] as Map<String, dynamic>;
        final newTokens = AuthTokens.fromJson(data);

        // Simpan token baru termasuk rotasi refresh token
        await tokenStorage.saveTokens(newTokens);

        _refreshCompleter!.complete(newTokens.accessToken);
        return newTokens.accessToken;
      } else {
        await _handleSessionTermination(responseBody);
        _refreshCompleter!.complete(null);
        return null;
      }
    } on DioException catch (dioErr) {
      final statusCode = dioErr.response?.statusCode;
      final errorData = dioErr.response?.data;

      // Bedakan error autentikasi definitif (401 / 403 / 422) vs error jaringan sementara (5xx / timeout)
      if (statusCode == 401 || statusCode == 403 || statusCode == 422) {
        await _handleSessionTermination(errorData);
        _refreshCompleter!.complete(null);
      } else {
        // Transient error (koneksi terputus / 500) — jangan hapus sesi lokal
        _refreshCompleter!.complete(null);
      }
      return null;
    } catch (e) {
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      final finishedCompleter = _refreshCompleter;
      _refreshCompleter = null;
      if (finishedCompleter != null && !finishedCompleter.isCompleted) {
        finishedCompleter.complete(null);
      }
    }
  }

  /// Menghapus kredensial sesi lokal dan memicu notifikasi sesi berakhir
  Future<void> _handleSessionTermination(dynamic responseData) async {
    await tokenStorage.clearTokens();

    String message = ApiConstants.sessionExpiredMessage;
    if (responseData is Map<String, dynamic>) {
      final errorMap = responseData['error'];
      if (errorMap is Map<String, dynamic>) {
        final code = errorMap['code'];
        if (code == ApiConstants.errorExpiredRefreshToken) {
          message = 'Sesi Anda telah kedaluwarsa. Silakan login kembali.';
        } else if (code == ApiConstants.errorInvalidRefreshToken) {
          message = 'Sesi Anda tidak lagi valid. Silakan login kembali.';
        } else if (errorMap['message'] != null) {
          message = errorMap['message'].toString();
        }
      }
    }

    onSessionExpired?.call(message);
  }

  bool _isPublicPath(String path) {
    return path.contains(ApiConstants.loginEndpoint) ||
        path.contains(ApiConstants.registerEndpoint) ||
        path.contains(ApiConstants.refreshEndpoint);
  }
}
