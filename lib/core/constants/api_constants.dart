/// Konstanta endpoint API, storage key, dan error code untuk Recovera.
class ApiConstants {
  ApiConstants._();

  /// Default Base URL backend Recovera (dapat dioverride via konfigurasi lingkungan)
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://recovera-production-88f9.up.railway.app',
  );

  // ── Auth Endpoints ──────────────────────────────────────────────────────────
  static const String registerEndpoint = '/auth/register';
  static const String loginEndpoint = '/auth/login';
  static const String refreshEndpoint = '/auth/refresh';
  static const String logoutEndpoint = '/auth/logout';
  static const String profileEndpoint = '/profile';

  // ── Storage Keys (flutter_secure_storage) ────────────────────────────────────
  static const String keyAccessToken = 'recovera_access_token';
  static const String keyRefreshToken = 'recovera_refresh_token';
  static const String keyTokenType = 'recovera_token_type';
  static const String keyExpiresIn = 'recovera_expires_in';
  static const String keyUserId = 'recovera_user_id';
  static const String keyUserRole = 'recovera_user_role';
  static const String keyUserName = 'recovera_user_name';

  // ── Session Error Codes ─────────────────────────────────────────────────────
  static const String errorExpiredRefreshToken = 'EXPIRED_REFRESH_TOKEN';
  static const String errorInvalidRefreshToken = 'INVALID_REFRESH_TOKEN';
  static const String errorUserNotFound = 'USER_NOT_FOUND';
  static const String errorValidationError = 'VALIDATION_ERROR';

  // ── Default Messages ────────────────────────────────────────────────────────
  static const String sessionExpiredMessage =
      'Sesi Anda telah berakhir. Silakan login kembali.';
}
