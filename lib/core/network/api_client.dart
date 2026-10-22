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
        _customAdapter = adapter,
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

    final refreshDio = Dio(
      BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    if (adapter != null) {
      refreshDio.httpClientAdapter = adapter;
    }

    _authInterceptor = AuthInterceptor(
      tokenStorage: _tokenStorage,
      refreshDio: refreshDio,
      onSessionExpired: onSessionExpired ??
          (message) => AppNavigator.handleSessionExpired(message: message),
    );

    _dio.interceptors.add(_authInterceptor);
  }

  final ITokenStorage _tokenStorage;
  final Dio _dio;
  final HttpClientAdapter? _customAdapter;
  late final AuthInterceptor _authInterceptor;

  Dio get dio => _dio;
  ITokenStorage get tokenStorage => _tokenStorage;
  AuthInterceptor get authInterceptor => _authInterceptor;

  /// Update Base URL secara dinamis
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
    _authInterceptor.updateBaseUrl(newBaseUrl);
  }

  // ── Helper HTTP Methods ──────────────────────────────────────────────────

  Future<Response<T>> _executeCustomAdapterRequest<T>(
    String path, {
    required String method,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final headers = <String, dynamic>{}
      ..addAll(_dio.options.headers)
      ..addAll(options?.headers ?? {});

    final requestOptions = RequestOptions(
      baseUrl: _dio.options.baseUrl,
      path: path,
      method: method,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      headers: headers,
      extra: options?.extra ?? {},
      responseType: options?.responseType ?? ResponseType.json,
      contentType: data is FormData
          ? null
          : (options?.contentType ?? _dio.options.contentType),
    );

    // Jalankan request interceptors (misal: penyuntikan header Authorization)
    for (final interceptor in _dio.interceptors) {
      final handler = RequestInterceptorHandler();
      try {
        if (interceptor is AuthInterceptor) {
          await interceptor.onRequest(requestOptions, handler);
        } else {
          interceptor.onRequest(requestOptions, handler);
        }
      } catch (_) {}
    }

    final responseBody = await _customAdapter!.fetch(
      requestOptions,
      null,
      cancelToken?.whenCancel,
    );

    final dynamic rawData = await _dio.transformer.transformResponse(requestOptions, responseBody);

    final response = Response<T>(
      requestOptions: requestOptions,
      data: rawData as T,
      statusCode: responseBody.statusCode,
      statusMessage: responseBody.statusMessage,
      headers: Headers.fromMap(responseBody.headers),
    );

    if (responseBody.statusCode < 200 || responseBody.statusCode >= 300) {
      throw DioException(
        requestOptions: requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    return response;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    if (_customAdapter != null) {
      return _executeCustomAdapterRequest<T>(
        path,
        method: 'GET',
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    }
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
    if (_customAdapter != null) {
      return _executeCustomAdapterRequest<T>(
        path,
        method: 'POST',
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    }
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
    if (_customAdapter != null) {
      return _executeCustomAdapterRequest<T>(
        path,
        method: 'PATCH',
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    }
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
    if (_customAdapter != null) {
      return _executeCustomAdapterRequest<T>(
        path,
        method: 'DELETE',
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    }
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
