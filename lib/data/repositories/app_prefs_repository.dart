import 'dart:convert';
import '../database/database_constants.dart';
import '../services/local_database_service.dart';

/// Repository managing local persistent application preferences via SQLite `app_prefs`.
/// Satisfies PRD US-12 (biometric toggle, timezone preference, last exchange rate cache).
class AppPrefsRepository {
  final LocalDatabaseService _localDb;

  AppPrefsRepository({LocalDatabaseService? localDb})
      : _localDb = localDb ?? LocalDatabaseService();

  // ===========================================================================
  // Biometric Authentication (US-02 & US-12)
  // ===========================================================================

  /// Check if biometric authentication is enabled by the user.
  Future<bool> isBiometricEnabled() async {
    final value = await _localDb.getPref(DatabaseConstants.prefBiometricEnabled);
    return value == 'true';
  }

  /// Toggle or update biometric authentication preference.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _localDb.setPref(DatabaseConstants.prefBiometricEnabled, enabled.toString());
  }

  // ===========================================================================
  // Timezone Preference (US-10 & US-12)
  // ===========================================================================

  /// Get the active timezone display preference ('WIB', 'WITA', 'WIT', 'London').
  /// Defaults to 'WIB'.
  Future<String> getSelectedTimezone() async {
    final value = await _localDb.getPref(DatabaseConstants.prefSelectedTimezone);
    return value ?? 'WIB';
  }

  /// Set the active timezone display preference.
  Future<void> setSelectedTimezone(String timezone) async {
    await _localDb.setPref(DatabaseConstants.prefSelectedTimezone, timezone);
  }

  // ===========================================================================
  // Currency Exchange Rates (US-09 & US-12)
  // ===========================================================================

  /// Get the cached exchange rates map (e.g. {'USD': 0.000063, 'EUR': 0.000058, 'GBP': 0.000050}).
  /// Returns empty map if none cached.
  Future<Map<String, double>> getLastCurrencyRates() async {
    final value = await _localDb.getPref(DatabaseConstants.prefLastCurrencyRates);
    if (value == null || value.isEmpty) return {};

    try {
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  /// Cache the latest exchange rates into SQLite.
  Future<void> setLastCurrencyRates(Map<String, double> rates) async {
    final jsonStr = jsonEncode(rates);
    await _localDb.setPref(DatabaseConstants.prefLastCurrencyRates, jsonStr);
  }

  // ===========================================================================
  // Generic Preference Operations
  // ===========================================================================

  Future<String?> getString(String key) async {
    return await _localDb.getPref(key);
  }

  Future<void> setString(String key, String value) async {
    await _localDb.setPref(key, value);
  }

  Future<bool?> getBool(String key) async {
    final val = await _localDb.getPref(key);
    if (val == null) return null;
    return val == 'true';
  }

  Future<void> setBool(String key, bool value) async {
    await _localDb.setPref(key, value.toString());
  }

  Future<int?> getInt(String key) async {
    final val = await _localDb.getPref(key);
    if (val == null) return null;
    return int.tryParse(val);
  }

  Future<void> setInt(String key, int value) async {
    await _localDb.setPref(key, value.toString());
  }

  Future<void> deletePref(String key) async {
    await _localDb.deletePref(key);
  }

  Future<Map<String, String>> getAllPrefs() async {
    return await _localDb.getAllPrefs();
  }

  Future<void> clearAllPrefs() async {
    await _localDb.clearPrefs();
  }
}
