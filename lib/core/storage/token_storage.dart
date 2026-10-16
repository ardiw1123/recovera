import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

/// Model kredensial autentikasi hasil login atau refresh token.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
    this.expiresIn = 3600,
    this.userId,
    this.role,
    this.name,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final int? userId;
  final String? role;
  final String? name;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 3600,
      userId: json['user_id'] is int ? json['user_id'] as int : int.tryParse(json['user_id']?.toString() ?? ''),
      role: json['role'] as String?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
      if (name != null) 'name': name,
    };
  }

  AuthTokens copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    int? expiresIn,
    int? userId,
    String? role,
    String? name,
  }) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      expiresIn: expiresIn ?? this.expiresIn,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthTokens &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          tokenType == other.tokenType &&
          expiresIn == other.expiresIn &&
          userId == other.userId &&
          role == other.role &&
          name == other.name;

  @override
  int get hashCode =>
      accessToken.hashCode ^
      refreshToken.hashCode ^
      tokenType.hashCode ^
      expiresIn.hashCode ^
      userId.hashCode ^
      role.hashCode ^
      name.hashCode;
}

/// Kontrak penyimpanan token untuk mendukung enkripsi hardware KeyStore dan pengujian mock.
abstract class ITokenStorage {
  Future<void> saveTokens(AuthTokens tokens);
  Future<AuthTokens?> getTokens();
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> saveAccessToken(String accessToken);
  Future<void> saveRefreshToken(String refreshToken);
  Future<void> clearTokens();
  Future<bool> hasValidToken();
}

/// Implementasi penyimpanan token terenkripsi menggunakan [FlutterSecureStorage]
/// dengan jaminan proteksi Android KeyStore (EncryptedSharedPreferences).
class SecureTokenStorage implements ITokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  /// Konfigurasi Android KeyStore yang disyaratkan untuk audit keamanan
  static const AndroidOptions androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  /// Konfigurasi iOS Keychain
  static const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  @override
  Future<void> saveTokens(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(
        key: ApiConstants.keyAccessToken,
        value: tokens.accessToken,
        aOptions: androidOptions,
        iOptions: iosOptions,
      ),
      _storage.write(
        key: ApiConstants.keyRefreshToken,
        value: tokens.refreshToken,
        aOptions: androidOptions,
        iOptions: iosOptions,
      ),
      _storage.write(
        key: ApiConstants.keyTokenType,
        value: tokens.tokenType,
        aOptions: androidOptions,
        iOptions: iosOptions,
      ),
      _storage.write(
        key: ApiConstants.keyExpiresIn,
        value: tokens.expiresIn.toString(),
        aOptions: androidOptions,
        iOptions: iosOptions,
      ),
      if (tokens.userId != null)
        _storage.write(
          key: ApiConstants.keyUserId,
          value: tokens.userId.toString(),
          aOptions: androidOptions,
          iOptions: iosOptions,
        ),
      if (tokens.role != null)
        _storage.write(
          key: ApiConstants.keyUserRole,
          value: tokens.role,
          aOptions: androidOptions,
          iOptions: iosOptions,
        ),
      if (tokens.name != null)
        _storage.write(
          key: ApiConstants.keyUserName,
          value: tokens.name,
          aOptions: androidOptions,
          iOptions: iosOptions,
        ),
    ]);
  }

  @override
  Future<AuthTokens?> getTokens() async {
    final access = await _storage.read(
      key: ApiConstants.keyAccessToken,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );
    final refresh = await _storage.read(
      key: ApiConstants.keyRefreshToken,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );

    if (access == null || refresh == null) {
      return null;
    }

    final tokenType = await _storage.read(
          key: ApiConstants.keyTokenType,
          aOptions: androidOptions,
          iOptions: iosOptions,
        ) ??
        'bearer';
    final expiresInStr = await _storage.read(
      key: ApiConstants.keyExpiresIn,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );
    final userIdStr = await _storage.read(
      key: ApiConstants.keyUserId,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );
    final role = await _storage.read(
      key: ApiConstants.keyUserRole,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );
    final name = await _storage.read(
      key: ApiConstants.keyUserName,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );

    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      tokenType: tokenType,
      expiresIn: int.tryParse(expiresInStr ?? '') ?? 3600,
      userId: int.tryParse(userIdStr ?? ''),
      role: role,
      name: name,
    );
  }

  @override
  Future<String?> getAccessToken() {
    return _storage.read(
      key: ApiConstants.keyAccessToken,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );
  }

  @override
  Future<String?> getRefreshToken() {
    return _storage.read(
      key: ApiConstants.keyRefreshToken,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );
  }

  @override
  Future<void> saveAccessToken(String accessToken) {
    return _storage.write(
      key: ApiConstants.keyAccessToken,
      value: accessToken,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );
  }

  @override
  Future<void> saveRefreshToken(String refreshToken) {
    return _storage.write(
      key: ApiConstants.keyRefreshToken,
      value: refreshToken,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );
  }

  @override
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: ApiConstants.keyAccessToken, aOptions: androidOptions, iOptions: iosOptions),
      _storage.delete(key: ApiConstants.keyRefreshToken, aOptions: androidOptions, iOptions: iosOptions),
      _storage.delete(key: ApiConstants.keyTokenType, aOptions: androidOptions, iOptions: iosOptions),
      _storage.delete(key: ApiConstants.keyExpiresIn, aOptions: androidOptions, iOptions: iosOptions),
      _storage.delete(key: ApiConstants.keyUserId, aOptions: androidOptions, iOptions: iosOptions),
      _storage.delete(key: ApiConstants.keyUserRole, aOptions: androidOptions, iOptions: iosOptions),
      _storage.delete(key: ApiConstants.keyUserName, aOptions: androidOptions, iOptions: iosOptions),
    ]);
  }

  @override
  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}

/// Implementasi in-memory untuk unit testing tanpa platform channel Flutter
class InMemoryTokenStorage implements ITokenStorage {
  AuthTokens? _tokens;

  @override
  Future<void> saveTokens(AuthTokens tokens) async {
    _tokens = tokens;
  }

  @override
  Future<AuthTokens?> getTokens() async => _tokens;

  @override
  Future<String?> getAccessToken() async => _tokens?.accessToken;

  @override
  Future<String?> getRefreshToken() async => _tokens?.refreshToken;

  @override
  Future<void> saveAccessToken(String accessToken) async {
    if (_tokens != null) {
      _tokens = _tokens!.copyWith(accessToken: accessToken);
    } else {
      _tokens = AuthTokens(accessToken: accessToken, refreshToken: '');
    }
  }

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    if (_tokens != null) {
      _tokens = _tokens!.copyWith(refreshToken: refreshToken);
    } else {
      _tokens = AuthTokens(accessToken: '', refreshToken: refreshToken);
    }
  }

  @override
  Future<void> clearTokens() async {
    _tokens = null;
  }

  @override
  Future<bool> hasValidToken() async {
    return _tokens != null && _tokens!.accessToken.isNotEmpty;
  }
}
