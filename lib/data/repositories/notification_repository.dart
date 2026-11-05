import '../../core/network/api_client.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data = const {},
  });

  final int id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        type: json['type'] as String? ?? '',
        isRead: json['is_read'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
      );
}

class NotificationRepository {
  NotificationRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<AppNotification>> fetchNotifications() async {
    final response = await _client.get<Map<String, dynamic>>('/notifications');
    final body = response.data;
    if (body?['success'] != true) {
      throw StateError(
        body?['error']?['message']?.toString() ?? 'Gagal memuat notifikasi',
      );
    }
    final items = body?['data'] as List<dynamic>? ?? const [];
    return items
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> markAsRead(int notificationId) async {
    await _client.patch<Map<String, dynamic>>(
      '/notifications/$notificationId/read',
    );
  }
}
