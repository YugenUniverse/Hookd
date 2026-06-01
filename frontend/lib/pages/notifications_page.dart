import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/group_provider.dart';
import '../providers/notification_provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().loadNotifications();
    });
  }

  Future<void> _markAllRead() async {
    await context.read<NotificationProvider>().markAllAsRead();
  }

  Future<void> _markRead(AppNotification notif) async {
    if (notif.read) return;
    await context.read<NotificationProvider>().markAsRead(notif.id);
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
        child: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final notifications = provider.notifications;
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

  ({IconData icon, String title}) get _content => switch (notification.type) {
    'new_event' => (
      icon: Icons.event_note,
      title: notification.eventTitle.isNotEmpty
          ? 'New event: ${notification.eventTitle}'
          : 'New event',
    ),
    'badge_awarded' => (
      icon: Icons.emoji_events_outlined,
      title: notification.badgeName.isNotEmpty
          ? 'You earned: ${notification.badgeName}'
          : 'New badge earned!',
    ),
    'new_follower' => (
      icon: Icons.person_add_outlined,
      title: notification.followerName.isNotEmpty
          ? '${notification.followerName} started following you'
          : 'Someone followed you',
    ),
    'issue_status_changed' => (
      icon: Icons.update,
      title: notification.wallName.isNotEmpty
          ? 'Issue on ${notification.wallName} is now '
              '${notification.newStatus.isNotEmpty ? notification.newStatus : "updated"}'
          : 'An issue status was updated',
    ),
    'new_issue' => (
      icon: Icons.warning_outlined,
      title: notification.wallName.isNotEmpty
          ? 'New issue on ${notification.wallName}'
          : 'New issue reported',
    ),
    _ => (icon: Icons.notifications_outlined, title: 'Notification'),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.read;
    final (:icon, :title) = _content;
    return ListTile(
      onTap: onTap,
      tileColor: unread ? theme.colorScheme.primaryContainer.withAlpha(60) : null,
      leading: Icon(icon, color: unread ? theme.colorScheme.primary : null),
      title: Text(
        title,
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
