import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../navigation/app_navigator.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// Client HTTP terpusat untuk aplikasi Recovera yang terhubung dengan [AuthInterceptor]
/// dan [SecureTokenStorage].
class ApiClient {
  ApiClient({
    String? baseUrl,
    ITokenStorage? tokenStorage,
    Dio? dio,
    SessionExpiredCallback? onSessionExpired,
    HttpClientAdapter? adapter,
  })  : _tokenStorage = tokenStorage ?? SecureTokenStorage(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConstants.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    if (adapter != null) {
      _dio.httpClientAdapter = adapter;
    }

    _authInterceptor = AuthInterceptor(
      tokenStorage: _tokenStorage,
      onSessionExpired: onSessionExpired ??
          (message) => AppNavigator.handleSessionExpired(message: message),
    );

    _dio.interceptors.add(_authInterceptor);
  }

  final ITokenStorage _tokenStorage;
  final Dio _dio;
  late final AuthInterceptor _authInterceptor;

  Dio get dio => _dio;
  ITokenStorage get tokenStorage => _tokenStorage;
  AuthInterceptor get authInterceptor => _authInterceptor;

  /// Update Base URL secara dinamis
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  // ── Helper HTTP Methods ──────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
