import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/auth_interceptor.dart';
import '../../core/storage/token_storage.dart';
import '../../features/auth/models/user_profile.dart';

/// Service untuk memanggil API autentikasi backend FastAPI Recovera
class AuthApiService {
  AuthApiService({required this.client});

  final ApiClient client;

  /// Registrasi akun baru (Seller / Buyer)
  Future<AuthTokens> register({
    required String email,
    required String password,
    required String role,
    required String name,
    String? phone,
    String? companyName,
    String? businessType,
    String? address,
    String? city,
  }) async {
    final payload = <String, dynamic>{
      'email': email,
      'password': password,
      'role': role,
      'name': name,
    };
    if (phone != null) payload['phone'] = phone;
    if (companyName != null) payload['company_name'] = companyName;
    if (businessType != null) payload['business_type'] = businessType;
    if (address != null) payload['address'] = address;
    if (city != null) payload['city'] = city;

    try {
      final response = await client.post<Map<String, dynamic>>(
        ApiConstants.registerEndpoint,
        data: payload,
        options: Options(extra: {AuthInterceptor.noAuthExtraKey: true}),
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        final error = data?['error']?['message'] ?? 'Registrasi gagal';
        final code = data?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      return AuthTokens.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Registrasi gagal');
    }
  }

  /// Login dengan email dan password
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.post<Map<String, dynamic>>(
        ApiConstants.loginEndpoint,
        data: {
          'email': email,
          'password': password,
        },
        options: Options(extra: {AuthInterceptor.noAuthExtraKey: true}),
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        final error = data?['error']?['message'] ?? 'Login gagal';
        final code = data?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      return AuthTokens.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Login gagal');
    }
  }

  /// Rotasi refresh token secara eksplisit
  Future<AuthTokens> refreshToken(String refreshToken) async {
    try {
      final response = await client.post<Map<String, dynamic>>(
        ApiConstants.refreshEndpoint,
        data: {'refresh_token': refreshToken},
        options: Options(extra: {AuthInterceptor.noAuthExtraKey: true}),
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        final error = data?['error']?['message'] ?? 'Refresh token gagal';
        final code = data?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      return AuthTokens.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Refresh token gagal');
    }
  }

  /// Logout dan revocasi refresh token di backend
  Future<void> logout({String? refreshToken}) async {
    try {
      await client.post<Map<String, dynamic>>(
        ApiConstants.logoutEndpoint,
        data: refreshToken != null ? {'refresh_token': refreshToken} : null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Logout gagal');
    }
  }

  /// Ambil profil pengguna saat ini (request terautentikasi otomatis via Bearer token)
  Future<UserProfile> getProfile() async {
    try {
      final response = await client.get<Map<String, dynamic>>(
        ApiConstants.profileEndpoint,
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        final error = data?['error']?['message'] ?? 'Gagal memuat profil';
        final code = data?['error']?['code'] as String?;
        throw ApiException(error, code: code);
      }

      return UserProfile.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e, 'Gagal memuat profil');
    }
  }
}
