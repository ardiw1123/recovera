import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model data hasil pencarian lokasi atau tempat
class PlaceSearchResult {
  const PlaceSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    return PlaceSearchResult(
      displayName: json['display_name'] as String? ?? '',
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '') ?? 0.0,
    );
  }

  @override
  String toString() => 'PlaceSearchResult($displayName, lat: $latitude, lon: $longitude)';
}

/// Model data hasil reverse geocoding koordinat GPS menjadi alamat terbaca
class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    required this.displayName,
    required this.road,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final String road;
  final String city;
  final double latitude;
  final double longitude;

  @override
  String toString() => 'ReverseGeocodeResult(road: $road, city: $city, lat: $latitude, lon: $longitude)';
}

/// Service untuk mencari tempat atau lokasi berdasarkan kata kunci dan koordinat (Nominatim OpenStreetMap)
class PlaceSearchService {
  PlaceSearchService({http.Client? client}) : _client = client ?? http.Client();

  static PlaceSearchService instance = PlaceSearchService();

  final http.Client _client;

  // Mock list untuk testing jika dibutuhkan
  static List<PlaceSearchResult>? mockSearchResults;
  static ReverseGeocodeResult? mockReverseResult;

  /// Mencari tempat berdasarkan nama jalan, kota, atau tempat menarik
  Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    if (mockSearchResults != null) {
      return mockSearchResults!;
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(trimmed)}&format=json&limit=5&countrycodes=id',
      );

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'RecoveraApp/1.0 (contact: support@recovera.id)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => PlaceSearchResult.fromJson(item))
            .where((result) => result.latitude != 0.0 || result.longitude != 0.0)
            .toList();
      }
      return const [];
    } catch (_) {
      // Fallback saat offline atau error jaringan tanpa crash
      return const [];
    }
  }

  /// Mengonversi koordinat lintang dan bujur menjadi alamat jalan serta kota yang akurat
  Future<ReverseGeocodeResult> reverseGeocode(double latitude, double longitude) async {
    if (mockReverseResult != null) {
      return mockReverseResult!;
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$latitude&lon=$longitude&format=json&addressdetails=1',
      );

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'RecoveraApp/1.0 (contact: support@recovera.id)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String? ?? '';
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final roadPart = address['road'] as String? ??
            address['pedestrian'] as String? ??
            address['suburb'] as String? ??
            address['neighbourhood'] as String? ??
            '';

        final cityPart = address['city'] as String? ??
            address['city_district'] as String? ??
            address['town'] as String? ??
            address['municipality'] as String? ??
            address['county'] as String? ??
            address['state'] as String? ??
            'Indonesia';

        String finalAddress = displayName;
        if (roadPart.isNotEmpty) {
          final houseNumber = address['house_number'] as String?;
          final street = houseNumber != null ? '$roadPart No. $houseNumber' : roadPart;
          final suburb = address['suburb'] as String?;
          finalAddress = suburb != null && suburb != roadPart ? '$street, $suburb' : street;
        }

        return ReverseGeocodeResult(
          displayName: displayName.isNotEmpty ? displayName : 'Titik Lokasi Terpilih',
          road: finalAddress.isNotEmpty ? finalAddress : 'Koordinat (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})',
          city: cityPart,
          latitude: latitude,
          longitude: longitude,
        );
      }
    } catch (_) {}

    return ReverseGeocodeResult(
      displayName: 'Koordinat (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})',
      road: 'Koordinat (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})',
      city: 'Lokasi Terpilih',
      latitude: latitude,
      longitude: longitude,
    );
  }
}
