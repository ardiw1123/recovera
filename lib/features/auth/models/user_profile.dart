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

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] as Map<String, dynamic>?;
    final buyer = json['buyer'] as Map<String, dynamic>?;

    return UserProfile(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'buyer',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      companyName: (seller?['company_name'] as String?) ?? json['company_name'] as String?,
      businessType: (buyer?['business_type'] as String?) ?? json['business_type'] as String?,
      address: (seller?['address'] as String?) ?? (buyer?['address'] as String?) ?? json['address'] as String?,
      city: (seller?['city'] as String?) ?? json['city'] as String?,
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
    };
  }
}
