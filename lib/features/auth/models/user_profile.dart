/// Model profil pengguna Recovera
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    this.phone,
    this.photoUrl,
    this.companyName,
    this.businessType,
    this.address,
    this.city,
    this.baseLat,
    this.baseLng,
    this.warehouseLat,
    this.warehouseLng,
  });

  final int id;
  final String email;
  final String role;
  final String name;
  final String? phone;
  final String? photoUrl;
  final String? companyName;
  final String? businessType;
  final String? address;
  final String? city;
  final double? baseLat;
  final double? baseLng;
  final double? warehouseLat;
  final double? warehouseLng;

  /// Koordinat umum pengguna (baseLat untuk buyer, warehouseLat untuk seller)
  double? get lat => baseLat ?? warehouseLat;
  double? get lng => baseLng ?? warehouseLng;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] as Map<String, dynamic>?;
    final buyer = json['buyer'] as Map<String, dynamic>?;

    double? parseCoordinate(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    int parseId(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? 0;
    }

    return UserProfile(
      id: parseId(json['id']),
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'buyer',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      companyName: (seller?['company_name'] as String?) ?? json['company_name'] as String?,
      businessType: (buyer?['business_type'] as String?) ?? json['business_type'] as String?,
      address: (seller?['address'] as String?) ?? (buyer?['address'] as String?) ?? json['address'] as String?,
      city: (seller?['city'] as String?) ?? json['city'] as String?,
      baseLat: parseCoordinate(buyer?['base_lat'] ?? json['base_lat'] ?? json['lat']),
      baseLng: parseCoordinate(buyer?['base_lng'] ?? json['base_lng'] ?? json['lng']),
      warehouseLat: parseCoordinate(seller?['warehouse_lat'] ?? json['warehouse_lat']),
      warehouseLng: parseCoordinate(seller?['warehouse_lng'] ?? json['warehouse_lng']),
    );
  }

  UserProfile copyWith({
    int? id,
    String? email,
    String? role,
    String? name,
    String? phone,
    String? photoUrl,
    String? companyName,
    String? businessType,
    String? address,
    String? city,
    double? baseLat,
    double? baseLng,
    double? warehouseLat,
    double? warehouseLng,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      companyName: companyName ?? this.companyName,
      businessType: businessType ?? this.businessType,
      address: address ?? this.address,
      city: city ?? this.city,
      baseLat: baseLat ?? this.baseLat,
      baseLng: baseLng ?? this.baseLng,
      warehouseLat: warehouseLat ?? this.warehouseLat,
      warehouseLng: warehouseLng ?? this.warehouseLng,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'name': name,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (companyName != null) 'company_name': companyName,
      if (businessType != null) 'business_type': businessType,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (baseLat != null) 'base_lat': baseLat,
      if (baseLng != null) 'base_lng': baseLng,
      if (warehouseLat != null) 'warehouse_lat': warehouseLat,
      if (warehouseLng != null) 'warehouse_lng': warehouseLng,
    };
  }
}
