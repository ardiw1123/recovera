import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
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

    final response = await client.post<Map<String, dynamic>>(
      ApiConstants.registerEndpoint,
      data: payload,
      options: Options(extra: {AuthInterceptor.noAuthExtraKey: true}),
    );

    final data = response.data;
    if (data == null || data['success'] != true) {
      final error = data?['error']?['message'] ?? 'Registrasi gagal';
      throw Exception(error);
    }

    return AuthTokens.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Login dengan email dan password
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
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
      throw Exception(error);
    }

    return AuthTokens.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Rotasi refresh token secara eksplisit
  Future<AuthTokens> refreshToken(String refreshToken) async {
    final response = await client.post<Map<String, dynamic>>(
      ApiConstants.refreshEndpoint,
      data: {'refresh_token': refreshToken},
      options: Options(extra: {AuthInterceptor.noAuthExtraKey: true}),
    );

    final data = response.data;
    if (data == null || data['success'] != true) {
      final error = data?['error']?['message'] ?? 'Refresh token gagal';
      throw Exception(error);
    }

    return AuthTokens.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Logout dan revocasi refresh token di backend
  Future<void> logout({String? refreshToken}) async {
    await client.post<Map<String, dynamic>>(
      ApiConstants.logoutEndpoint,
      data: refreshToken != null ? {'refresh_token': refreshToken} : null,
    );
  }

  /// Ambil profil pengguna saat ini (request terautentikasi otomatis via Bearer token)
  Future<UserProfile> getProfile() async {
    final response = await client.get<Map<String, dynamic>>(
      ApiConstants.profileEndpoint,
    );

    final data = response.data;
    if (data == null || data['success'] != true) {
      final error = data?['error']?['message'] ?? 'Gagal memuat profil';
      throw Exception(error);
    }

    return UserProfile.fromJson(data['data'] as Map<String, dynamic>);
  }
}
