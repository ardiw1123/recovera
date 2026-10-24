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
  Future<bool> authenticate({required String reason}) async {
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
        options: const AuthenticationOptions(
          stickyAuth: true,     // Tetap aktif jika app berpindah sebentar
          biometricOnly: false, // Izinkan fallback PIN/Pola HP jika sensor basah/gagal
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
}
