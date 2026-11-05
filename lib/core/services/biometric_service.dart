import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

/// Service Reusable untuk autentikasi biometrik (Fingerprint / Face ID)
/// dan pengelolaan preferensi/token aman (US-01, US-02, PB-016, PB-017).
/// Mendukung eksekusi di Android (native fingerprint) dan Chrome/Web (simulasi testing).
class BiometricService {
  // Singleton pattern agar mudah dipanggil dari mana saja
  static final BiometricService instance = BiometricService._internal();
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // In-memory fallback untuk web browser (Chrome) & safe offline
  static final Map<String, String> _webMemoryStorage = {};

  // Keys untuk penyimpanan aman (Android Keystore / iOS Keychain)
  static const String _keyAccessToken = ApiConstants.keyAccessToken;
  static const String _keyRefreshToken = ApiConstants.keyRefreshToken;
  static const String _keyBiometricEnabled = 'recovera_biometric_enabled';
  static const String _keyBiometricUserId = 'recovera_biometric_user_id';
  static const String _keyBiometricUserName = 'recovera_biometric_user_name';
  static const String _keyBiometricUserEmail = 'recovera_biometric_user_email';
  static const String _keyBiometricUserRole = 'recovera_biometric_user_role';
  static const String _keyBiometricCompanyName = 'recovera_biometric_company_name';

  /// 1. Cek apakah HP/perangkat memiliki hardware biometrik & sidik jari terdaftar
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return true; // Web simulated biometric for Chrome testing
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isDeviceSupported) return false;

      final List<BiometricType> availableBiometrics =
          await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty || canCheck || isDeviceSupported;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 2. Fungsi Reusable untuk memicu Pop-up Sidik Jari (Login & Step-up Checkout)
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    if (kIsWeb) {
      // Browser Web: Simulasi autentikasi biometrik berhasil untuk testing UI
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true, // Tetap aktif jika app berpindah sebentar
          biometricOnly: biometricOnly, // Murni biometrik sidik jari (tanpa PIN HP)
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      // Sesuai AC US-02: Jika gagal/dibatalkan, jangan crash, kembalikan false
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 3. Simpan Token setelah Login Berhasil (US-01)
  Future<void> saveSessionTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _webMemoryStorage[_keyAccessToken] = accessToken;
    _webMemoryStorage[_keyRefreshToken] = refreshToken;
    _webMemoryStorage['access_token'] = accessToken;
    _webMemoryStorage['refresh_token'] = refreshToken;
    if (kIsWeb) return;

    try {
      await _secureStorage.write(key: _keyAccessToken, value: accessToken);
      await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
      await _secureStorage.write(key: 'access_token', value: accessToken);
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    } catch (_) {}
  }

  /// 4. Ambil Refresh Token untuk Login Biometrik
  Future<String?> getRefreshToken() async {
    if (kIsWeb) {
      return _webMemoryStorage[_keyRefreshToken] ?? _webMemoryStorage['refresh_token'];
    }
    try {
      final token = await _secureStorage.read(key: _keyRefreshToken);
      if (token != null && token.isNotEmpty) return token;
      return await _secureStorage.read(key: 'refresh_token');
    } catch (_) {
      return _webMemoryStorage[_keyRefreshToken] ?? _webMemoryStorage['refresh_token'];
    }
  }

  /// 5. Cek & Ubah Status Toggle Biometrik (PB-016)
  Future<bool> isBiometricLoginEnabled() async {
    if (kIsWeb) {
      final val = _webMemoryStorage[_keyBiometricEnabled] ?? _webMemoryStorage['biometric_enabled'];
      return val == 'true';
    }
    try {
      final val = await _secureStorage.read(key: _keyBiometricEnabled);
      if (val != null) return val == 'true';
      final legacyVal = await _secureStorage.read(key: 'biometric_enabled');
      return legacyVal == 'true';
    } catch (_) {
      final val = _webMemoryStorage[_keyBiometricEnabled] ?? _webMemoryStorage['biometric_enabled'];
      return val == 'true';
    }
  }

  Future<void> setBiometricLoginEnabled(bool enabled) async {
    _webMemoryStorage[_keyBiometricEnabled] = enabled.toString();
    _webMemoryStorage['biometric_enabled'] = enabled.toString();
    if (kIsWeb) return;

    try {
      await _secureStorage.write(
        key: _keyBiometricEnabled,
        value: enabled.toString(),
      );
      await _secureStorage.write(
        key: 'biometric_enabled',
        value: enabled.toString(),
      );
    } catch (_) {}
  }

  /// 6. Hapus Token saat Logout (PB-024)
  Future<void> clearSession() async {
    _webMemoryStorage.remove(_keyAccessToken);
    _webMemoryStorage.remove(_keyRefreshToken);
    _webMemoryStorage.remove('access_token');
    _webMemoryStorage.remove('refresh_token');
    if (kIsWeb) return;

    try {
      await _secureStorage.delete(key: _keyAccessToken);
      await _secureStorage.delete(key: _keyRefreshToken);
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
    } catch (_) {}
  }

  /// 7. Ikat Akun Pengguna yang Mengaktifkan Biometrik di Pengaturan Profil
  Future<void> bindUser({
    required int userId,
    required String name,
    required String email,
    required String role,
    String? companyName,
    required String refreshToken,
  }) async {
    _webMemoryStorage[_keyBiometricUserId] = userId.toString();
    _webMemoryStorage[_keyBiometricUserName] = name;
    _webMemoryStorage[_keyBiometricUserEmail] = email;
    _webMemoryStorage[_keyBiometricUserRole] = role;
    if (companyName != null) {
      _webMemoryStorage[_keyBiometricCompanyName] = companyName;
    }
    _webMemoryStorage[_keyRefreshToken] = refreshToken;

    if (!kIsWeb) {
      try {
        await _secureStorage.write(
          key: _keyBiometricUserId,
          value: userId.toString(),
        );
        await _secureStorage.write(
          key: _keyBiometricUserName,
          value: name,
        );
        await _secureStorage.write(
          key: _keyBiometricUserEmail,
          value: email,
        );
        await _secureStorage.write(
          key: _keyBiometricUserRole,
          value: role,
        );
        if (companyName != null) {
          await _secureStorage.write(
            key: _keyBiometricCompanyName,
            value: companyName,
          );
        }
        await _secureStorage.write(
          key: _keyRefreshToken,
          value: refreshToken,
        );
      } catch (_) {}
    }
  }

  /// 8. Ambil Data Akun yang Terikat Biometrik
  Future<Map<String, String?>?> getBoundUser() async {
    if (kIsWeb) {
      final name = _webMemoryStorage[_keyBiometricUserName];
      if (name == null || name.isEmpty) return null;
      return {
        'id': _webMemoryStorage[_keyBiometricUserId],
        'name': name,
        'email': _webMemoryStorage[_keyBiometricUserEmail],
        'role': _webMemoryStorage[_keyBiometricUserRole],
        'company_name': _webMemoryStorage[_keyBiometricCompanyName],
      };
    }
    try {
      final name = await _secureStorage.read(key: _keyBiometricUserName);
      if (name == null || name.isEmpty) return null;
      final id = await _secureStorage.read(key: _keyBiometricUserId);
      final email = await _secureStorage.read(key: _keyBiometricUserEmail);
      final role = await _secureStorage.read(key: _keyBiometricUserRole);
      final companyName =
          await _secureStorage.read(key: _keyBiometricCompanyName);
      return {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'company_name': companyName,
      };
    } catch (_) {
      final name = _webMemoryStorage[_keyBiometricUserName];
      if (name == null || name.isEmpty) return null;
      return {
        'id': _webMemoryStorage[_keyBiometricUserId],
        'name': name,
        'email': _webMemoryStorage[_keyBiometricUserEmail],
        'role': _webMemoryStorage[_keyBiometricUserRole],
        'company_name': _webMemoryStorage[_keyBiometricCompanyName],
      };
    }
  }

  /// 9. Lepas Ikatan Biometrik saat Dinonaktifkan di Pengaturan
  Future<void> unbindUser() async {
    _webMemoryStorage.remove(_keyBiometricUserId);
    _webMemoryStorage.remove(_keyBiometricUserName);
    _webMemoryStorage.remove(_keyBiometricUserEmail);
    _webMemoryStorage.remove(_keyBiometricUserRole);
    _webMemoryStorage.remove(_keyBiometricCompanyName);
    await setBiometricLoginEnabled(false);

    if (!kIsWeb) {
      try {
        await _secureStorage.delete(key: _keyBiometricUserId);
        await _secureStorage.delete(key: _keyBiometricUserName);
        await _secureStorage.delete(key: _keyBiometricUserEmail);
        await _secureStorage.delete(key: _keyBiometricUserRole);
        await _secureStorage.delete(key: _keyBiometricCompanyName);
      } catch (_) {}
    }
  }
}
