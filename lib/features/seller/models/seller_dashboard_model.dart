// Data model for seller dashboard API response
// Endpoint: GET /listings/seller/dashboard

class SellerDashboardData {
  final String companyName;
  final int activeListingsCount;
  final int prevMonthActiveCount;
  final int currentMonthOrdersCount;
  final int prevMonthOrdersCount;
  final List<NearExpiryItem> nearExpiryListings;
  final List<RecentActivity> recentActivities;

  const SellerDashboardData({
    required this.companyName,
    required this.activeListingsCount,
    required this.prevMonthActiveCount,
    required this.currentMonthOrdersCount,
    required this.prevMonthOrdersCount,
    required this.nearExpiryListings,
    required this.recentActivities,
  });

  factory SellerDashboardData.fromJson(Map<String, dynamic> json) {
    return SellerDashboardData(
      companyName: json['company_name'] as String? ?? '',
      activeListingsCount: (json['active_listings_count'] as num?)?.toInt() ?? 0,
      prevMonthActiveCount: (json['prev_month_active_count'] as num?)?.toInt() ?? 0,
      currentMonthOrdersCount: (json['current_month_orders_count'] as num?)?.toInt() ?? 0,
      prevMonthOrdersCount: (json['prev_month_orders_count'] as num?)?.toInt() ?? 0,
      nearExpiryListings: (json['near_expiry_listings'] as List<dynamic>?)
          ?.map((item) => NearExpiryItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      recentActivities: (json['recent_activities'] as List<dynamic>?)
          ?.map((item) => RecentActivity.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_name': companyName,
      'active_listings_count': activeListingsCount,
      'prev_month_active_count': prevMonthActiveCount,
      'current_month_orders_count': currentMonthOrdersCount,
      'prev_month_orders_count': prevMonthOrdersCount,
      'near_expiry_listings': nearExpiryListings.map((item) => item.toJson()).toList(),
      'recent_activities': recentActivities.map((item) => item.toJson()).toList(),
    };
  }
}

/// Model untuk satu item stok mendekati expired
class NearExpiryItem {
  final int id;
  final String productName;
  final int daysRemaining;
  final int qty;
  final String unit;
  final String category;

  const NearExpiryItem({
    required this.id,
    required this.productName,
    required this.daysRemaining,
    required this.qty,
    required this.unit,
    required this.category,
  });

  factory NearExpiryItem.fromJson(Map<String, dynamic> json) {
    return NearExpiryItem(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      productName: json['product_name'] as String? ?? '',
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String? ?? 'pcs',
      category: json['category'] as String? ?? 'Umum',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'days_remaining': daysRemaining,
      'qty': qty,
      'unit': unit,
      'category': category,
    };
  }
}

/// Model untuk satu aktivitas terbaru
class RecentActivity {
  final String type;
  final String title;
  final String subtitle;
  final String timestamp;

  const RecentActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'timestamp': timestamp,
    };
  }
}