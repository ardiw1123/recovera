import '../database/database_constants.dart';

/// Data model representing an application preference entry in SQLite table `app_prefs`.
/// Used for local persistence of biometrics, timezone, and currency rates per US-12.
class AppPrefModel {
  final String key;
  final String value;
  final String updatedAt;

  const AppPrefModel({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colPrefKey: key,
      DatabaseConstants.colPrefValue: value,
      DatabaseConstants.colPrefUpdatedAt: updatedAt,
    };
  }

  factory AppPrefModel.fromMap(Map<String, dynamic> map) {
    return AppPrefModel(
      key: map[DatabaseConstants.colPrefKey] as String,
      value: map[DatabaseConstants.colPrefValue] as String,
      updatedAt: map[DatabaseConstants.colPrefUpdatedAt] as String,
    );
  }

  factory AppPrefModel.create(String key, String value) {
    return AppPrefModel(
      key: key,
      value: value,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  AppPrefModel copyWith({
    String? key,
    String? value,
    String? updatedAt,
  }) {
    return AppPrefModel(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
