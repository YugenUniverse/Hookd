import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/conversation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'chat_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  List<Conversation> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final convs = await ApiService().getConversations();
      if (mounted) setState(() => _conversations = convs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: cs.error)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 56, color: cs.outline),
                          const SizedBox(height: 16),
                          Text('No messages yet',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Start a conversation from\na user\'s profile page.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _conversations.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) =>
                          _ConversationTile(conv: _conversations[i]),
                    ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conv;
  const _ConversationTile({required this.conv});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId = AuthService().currentUserId ?? '';
    final name = conv.displayName(currentUserId);
    final lastMsg = conv.lastMessage;
    final isGroup = conv.type == 'group';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.secondaryContainer,
        child: Icon(
          isGroup ? Icons.group : Icons.person,
          color: cs.onSecondaryContainer,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lastMsg != null)
            Text(
              _formatTime(conv.lastActivity),
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
      subtitle: lastMsg != null
          ? Text(
              '${lastMsg.senderUsername}: ${lastMsg.content}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: conv.hasUnread
                    ? cs.onSurface
                    : cs.onSurfaceVariant,
                fontWeight:
                    conv.hasUnread ? FontWeight.w600 : FontWeight.normal,
              ),
            )
          : Text(
              'No messages yet',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
      trailing: conv.hasUnread
          ? CircleAvatar(
              radius: 6,
              backgroundColor: cs.primary,
            )
          : null,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatPage(conversation: conv),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat.Hm().format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat.EEEE().format(dt);
    return DateFormat.yMd().format(dt);
  }
}
