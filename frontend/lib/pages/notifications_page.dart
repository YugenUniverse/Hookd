import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/api_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getNotifications();
  }

  void _refresh() {
    setState(() {
      _future = ApiService().getNotifications();
    });
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService().markAllNotificationsRead();
      _refresh();
    } catch (_) {}
  }

  Future<void> _markRead(AppNotification notif) async {
    if (notif.read) return;
    try {
      await ApiService().markNotificationRead(notif.id);
      _refresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.surface, cs.surfaceContainerHighest.withValues(alpha: 0.85)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final notifications = snapshot.data ?? [];
            if (notifications.isEmpty) {
              return const Center(child: Text('No notifications.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = notifications[i];
                return _NotificationTile(notification: n, onTap: () => _markRead(n));
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.read;
    return ListTile(
      onTap: onTap,
      tileColor: unread ? theme.colorScheme.primaryContainer.withAlpha(60) : null,
      leading: Icon(
        Icons.event_note,
        color: unread ? theme.colorScheme.primary : null,
      ),
      title: Text(
        notification.eventTitle.isNotEmpty
            ? 'New event: ${notification.eventTitle}'
            : 'New event',
        style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: notification.createdAt != null
          ? Text(_fmt(notification.createdAt!))
          : null,
      trailing: unread
          ? Icon(Icons.circle, size: 10, color: theme.colorScheme.primary)
          : null,
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
