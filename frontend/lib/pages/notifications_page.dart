import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/group_provider.dart';
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
                if (n.type == 'group_invite') {
                  return _GroupInviteTile(
                    notification: n,
                    onAccept: () async {
                      await context.read<GroupProvider>().acceptInvite(n.invitationId);
                      await _markRead(n);
                    },
                    onDecline: () async {
                      await context.read<GroupProvider>().declineInvite(n.invitationId);
                      await _markRead(n);
                    },
                  );
                }
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

class _GroupInviteTile extends StatefulWidget {
  const _GroupInviteTile({
    required this.notification,
    required this.onAccept,
    required this.onDecline,
  });

  final AppNotification notification;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  @override
  State<_GroupInviteTile> createState() => _GroupInviteTileState();
}

class _GroupInviteTileState extends State<_GroupInviteTile> {
  bool _busy = false;

  Future<void> _handle(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final n = widget.notification;
    final unread = !n.read;
    final inviter = n.invitedByName.isNotEmpty ? n.invitedByName : 'Someone';
    final groupName = n.groupName.isNotEmpty ? n.groupName : 'a group';

    return ListTile(
      tileColor: unread ? cs.primaryContainer.withAlpha(60) : null,
      leading: Icon(Icons.group, color: unread ? cs.primary : cs.onSurfaceVariant),
      title: Text(
        '$inviter invited you to join "$groupName"',
        style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n.createdAt != null)
            Text(
              '${n.createdAt!.day.toString().padLeft(2, '0')}/${n.createdAt!.month.toString().padLeft(2, '0')}/${n.createdAt!.year}',
            ),
          if (!n.read) ...[
            const SizedBox(height: 8),
            _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    children: [
                      FilledButton(
                        onPressed: () => _handle(widget.onAccept),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Accept'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _handle(widget.onDecline),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Decline'),
                      ),
                    ],
                  ),
          ],
        ],
      ),
      trailing: unread
          ? Icon(Icons.circle, size: 10, color: cs.primary)
          : null,
      isThreeLine: !n.read,
    );
  }
}
