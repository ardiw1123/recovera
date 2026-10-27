import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../data/repositories/notification_repository.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key, this.repository});

  final NotificationRepository? repository;

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  late final NotificationRepository _repository;
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? NotificationRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.fetchNotifications();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Notifikasi gagal dimuat. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(AppNotification item) async {
    if (!item.isRead) {
      setState(() {
        final index = _items.indexWhere((entry) => entry.id == item.id);
        if (index >= 0) {
          _items[index] = AppNotification(
            id: item.id,
            title: item.title,
            body: item.body,
            type: item.type,
            isRead: true,
            createdAt: item.createdAt,
            data: item.data,
          );
        }
      });
      try {
        await _repository.markAsRead(item.id);
      } catch (_) {
        if (mounted) _load();
      }
    }
    PushNotificationService.instance.handleTap({
      'type': item.type,
      ...item.data,
    });
  }

  String _relativeTime(DateTime date) {
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inMinutes < 1) return 'Baru saja';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} menit lalu';
    if (elapsed.inDays < 1) return '${elapsed.inHours} jam lalu';
    if (elapsed.inDays < 7) return '${elapsed.inDays} hari lalu';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifikasi')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              children: [
                const SizedBox(height: 140),
                Center(child: Text(_error!)),
                Center(
                  child: TextButton(
                    onPressed: _load,
                    child: const Text('Coba lagi'),
                  ),
                ),
              ],
            )
          : _items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 160),
                Icon(
                  Icons.notifications_off_outlined,
                  size: 42,
                  color: AppColors.slateText,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Belum ada notifikasi',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  onTap: () => _open(item),
                  leading: CircleAvatar(
                    backgroundColor: item.isRead
                        ? Colors.grey.shade100
                        : AppColors.primary.withValues(alpha: .1),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: item.isRead
                          ? AppColors.slateText
                          : AppColors.primary,
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: item.isRead
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.body),
                      const SizedBox(height: 4),
                      Text(
                        _relativeTime(item.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slateText,
                        ),
                      ),
                    ],
                  ),
                  trailing: item.isRead
                      ? null
                      : const Icon(Icons.circle, size: 9, color: Colors.red),
                );
              },
            ),
    ),
  );
}
