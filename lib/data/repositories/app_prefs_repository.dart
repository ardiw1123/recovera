import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/database_constants.dart';
import '../services/local_database_service.dart';

/// Repository managing local persistent application preferences via SQLite `app_prefs`.
/// Satisfies PRD US-12 (biometric toggle, timezone preference, last exchange rate cache).
/// Extends [ChangeNotifier] as a single source of truth for global Currency & Timezone state.
class AppPrefsRepository extends ChangeNotifier {
  final LocalDatabaseService _localDb;

  static AppPrefsRepository? _instance;
  static AppPrefsRepository get instance {
    _instance ??= AppPrefsRepository();
    return _instance!;
  }

  AppPrefsRepository({LocalDatabaseService? localDb})
      : _localDb = localDb ?? LocalDatabaseService();

  // In-memory state
  String _selectedCurrency = 'IDR';
  String _selectedTimezone = 'WIB';
  double _rateUSD = 15850.0;
  double _rateEUR = 17200.0;
  double _rateGBP = 20100.0;
  bool _isBiometricEnabledWeb = false;

  String get selectedCurrency => _selectedCurrency;
  String get selectedTimezone => _selectedTimezone;
  double get rateUSD => _rateUSD;
  double get rateEUR => _rateEUR;
  double get rateGBP => _rateGBP;

  /// Inisialisasi preferensi saat app startup
  Future<void> init() async {
    if (kIsWeb) {
      notifyListeners();
      return;
    }
    try {
      final cur = await getSelectedCurrency();
      final tz = await getSelectedTimezone();
      final rates = await getLastCurrencyRates();
      _selectedCurrency = cur;
      _selectedTimezone = tz;
      if (rates['USD'] != null && rates['USD']! > 0) _rateUSD = 1.0 / rates['USD']!;
      if (rates['EUR'] != null && rates['EUR']! > 0) _rateEUR = 1.0 / rates['EUR']!;
      if (rates['GBP'] != null && rates['GBP']! > 0) _rateGBP = 1.0 / rates['GBP']!;
      notifyListeners();
    } catch (_) {}
  }

  /// Update kurs live dan broadcast ke semua subscriber
  void updateLiveRates({
    required double rateUSD,
    required double rateEUR,
    required double rateGBP,
  }) {
    _rateUSD = rateUSD;
    _rateEUR = rateEUR;
    _rateGBP = rateGBP;
    notifyListeners();
  }

  /// Helper konversi harga IDR ke mata uang aktif
  double convertPrice(double idrPrice, [String? currency]) {
    final cur = currency ?? _selectedCurrency;
    switch (cur) {
      case 'USD':
        return _rateUSD > 0 ? (idrPrice / _rateUSD) : idrPrice;
      case 'EUR':
        return _rateEUR > 0 ? (idrPrice / _rateEUR) : idrPrice;
      case 'GBP':
        return _rateGBP > 0 ? (idrPrice / _rateGBP) : idrPrice;
      case 'IDR':
      default:
        return idrPrice;
    }
  }

  /// Format harga lengkap dengan simbol mata uang aktif (Rp, $, €, £)
  String formatPrice(double idrPrice, [String? currency]) {
    final cur = currency ?? _selectedCurrency;
    if (cur == 'IDR') {
      final val = idrPrice.toInt();
      final str = val.toString();
      final buf = StringBuffer();
      for (var i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
        buf.write(str[i]);
      }
      return 'Rp ${buf.toString()}';
    }
    final converted = convertPrice(idrPrice, cur);
    final symbol = cur == 'USD' ? '\$' : (cur == 'EUR' ? '€' : '£');
    return '$symbol${converted.toStringAsFixed(2)}';
  }

  /// Helper kalkulasi zona waktu aktif (WIB, WITA, WIT, London)
  Map<String, dynamic> getTimezoneInfo([String? timezone, DateTime? referenceTime]) {
    final tz = timezone ?? _selectedTimezone;
    final utc = (referenceTime ?? DateTime.now()).toUtc();
    switch (tz) {
      case 'WITA':
        final wita = utc.add(const Duration(hours: 8));
        return {
          'code': 'WITA',
          'offset': 'UTC+8',
          'drop': '19:00',
          'pickup': '22:00',
          'label': 'WITA (UTC+8)',
          'now': '${wita.hour.toString().padLeft(2, '0')}:${wita.minute.toString().padLeft(2, '0')}',
          'dateTime': wita,
        };
      case 'WIT':
        final wit = utc.add(const Duration(hours: 9));
        return {
          'code': 'WIT',
          'offset': 'UTC+9',
          'drop': '20:00',
          'pickup': '23:00',
          'label': 'WIT (UTC+9)',
          'now': '${wit.hour.toString().padLeft(2, '0')}:${wit.minute.toString().padLeft(2, '0')}',
          'dateTime': wit,
        };
      case 'London':
        final london = utc.add(const Duration(hours: 1));
        return {
          'code': 'BST',
          'offset': 'UTC+1',
          'drop': '12:00',
          'pickup': '15:00',
          'label': 'London (BST)',
          'now': '${london.hour.toString().padLeft(2, '0')}:${london.minute.toString().padLeft(2, '0')}',
          'dateTime': london,
        };
      case 'WIB':
      default:
        final wib = utc.add(const Duration(hours: 7));
        return {
          'code': 'WIB',
          'offset': 'UTC+7',
          'drop': '18:00',
          'pickup': '21:00',
          'label': 'WIB (UTC+7)',
          'now': '${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')}',
          'dateTime': wib,
        };
    }
  }

  // ===========================================================================
  // Biometric Authentication (US-02 & US-12)
  // ===========================================================================

  /// Check if biometric authentication is enabled by the user.
  Future<bool> isBiometricEnabled() async {
    if (kIsWeb) return _isBiometricEnabledWeb;
    try {
      final value = await _localDb
          .getPref(DatabaseConstants.prefBiometricEnabled)
          .timeout(const Duration(milliseconds: 500));
      return value == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Toggle or update biometric authentication preference.
  Future<void> setBiometricEnabled(bool enabled) async {
    _isBiometricEnabledWeb = enabled;
    if (kIsWeb) return;
    try {
      await _localDb
          .setPref(DatabaseConstants.prefBiometricEnabled, enabled.toString())
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {}
  }

  // ===========================================================================
  // Timezone Preference (US-10 & US-12)
  // ===========================================================================

  /// Get the active timezone display preference ('WIB', 'WITA', 'WIT', 'London').
  /// Defaults to 'WIB'.
  Future<String> getSelectedTimezone() async {
    if (kIsWeb) return _selectedTimezone;
    try {
      final value = await _localDb
          .getPref(DatabaseConstants.prefSelectedTimezone)
          .timeout(const Duration(milliseconds: 500));
      if (value != null && value.isNotEmpty) {
        _selectedTimezone = value;
      }
    } catch (_) {}
    return _selectedTimezone;
  }

  /// Set the active timezone display preference.
  Future<void> setSelectedTimezone(String timezone) async {
    _selectedTimezone = timezone;
    notifyListeners();
    if (kIsWeb) return;
    try {
      await _localDb
          .setPref(DatabaseConstants.prefSelectedTimezone, timezone)
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {}
  }

  // ===========================================================================
  // Currency Preference (US-09 & US-12)
  // ===========================================================================

  /// Get the active currency preference ('IDR', 'USD', 'EUR', 'GBP').
  /// Defaults to 'IDR'.
  Future<String> getSelectedCurrency() async {
    if (kIsWeb) return _selectedCurrency;
    try {
      final value = await _localDb
          .getPref(DatabaseConstants.prefSelectedCurrency)
          .timeout(const Duration(milliseconds: 500));
      if (value != null && value.isNotEmpty) {
        _selectedCurrency = value;
      }
    } catch (_) {}
    return _selectedCurrency;
  }

  /// Set the active currency preference.
  Future<void> setSelectedCurrency(String currency) async {
    _selectedCurrency = currency;
    notifyListeners();
    if (kIsWeb) return;
    try {
      await _localDb
          .setPref(DatabaseConstants.prefSelectedCurrency, currency)
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {}
  }

  // ===========================================================================
  // Currency Exchange Rates (US-09 & US-12)
  // ===========================================================================

  /// Get the cached exchange rates map (e.g. {'USD': 0.000063, 'EUR': 0.000058, 'GBP': 0.000050}).
  /// Returns empty map if none cached.
  Future<Map<String, double>> getLastCurrencyRates() async {
    if (kIsWeb) return {};
    try {
      final value = await _localDb
          .getPref(DatabaseConstants.prefLastCurrencyRates)
          .timeout(const Duration(milliseconds: 500));
      if (value == null || value.isEmpty) return {};

      final decoded = jsonDecode(value) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  /// Cache the latest exchange rates into SQLite.
  Future<void> setLastCurrencyRates(Map<String, double> rates) async {
    if (kIsWeb) return;
    try {
      final jsonStr = jsonEncode(rates);
      await _localDb
          .setPref(DatabaseConstants.prefLastCurrencyRates, jsonStr)
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {}
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
