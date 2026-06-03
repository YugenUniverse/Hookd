import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'climber_profile_page.dart';
import 'group_detail_page.dart';
import 'support_page.dart';

class ChatPage extends StatefulWidget {
  final Conversation conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _loadingHistory = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _sending = false;

  String? _typingUsername;
  Timer? _typingTimer;
  Timer? _stopTypingTimer;

  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;

  String get _convId => widget.conversation.id;
  String get _currentUserId => AuthService().currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _subscribeSocket();
    _scroll.addListener(_onScroll);
    ChatService().joinConversation(_convId);
    ApiService().markConversationRead(_convId).catchError((_) {});
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _typingSub?.cancel();
    _typingTimer?.cancel();
    _stopTypingTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    ChatService().leaveConversation(_convId);
    ChatService().markRead(_convId);
    super.dispose();
  }

  void _subscribeSocket() {
    _msgSub = ChatService().onNewMessage.listen((msg) {
      if (msg.conversationId == _convId && mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
        ChatService().markRead(_convId);
      }
    });

    _typingSub = ChatService().onTyping.listen((data) {
      if (data['conversationId'] == _convId && mounted) {
        final stopped = data['stopped'] == true;
        setState(() => _typingUsername = stopped ? null : data['username']?.toString());
      }
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels <= 60 && _hasMore && !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final msgs = await ApiService().getMessages(_convId);
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(msgs);
          _hasMore = msgs.length >= 30;
        });
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom(animated: false));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final oldest = _messages.first.createdAt.toUtc().toIso8601String();
      final older = await ApiService().getMessages(_convId, before: oldest);
      if (mounted) {
        setState(() {
          _messages.insertAll(0, older);
          _hasMore = older.length >= 30;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scroll.hasClients) return;
    if (animated) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  void _onInputChanged(String value) {
    if (value.trim().isEmpty) return;
    ChatService().emitTyping(_convId);
    _stopTypingTimer?.cancel();
    _stopTypingTimer = Timer(const Duration(seconds: 3), () {
      ChatService().emitStopTyping(_convId);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    _input.clear();
    _stopTypingTimer?.cancel();
    ChatService().emitStopTyping(_convId);
    setState(() => _sending = true);

    try {
      // Try socket first; fall back to REST
      final ChatMessage msg =
          await ChatService().sendMessage(_convId, text) ??
              await ApiService().sendMessageRest(_convId, text);

      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
        _input.text = text;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _title() {
    final conv = widget.conversation;
    if (conv.type == 'group') return conv.groupName ?? 'Group Chat';
    final other = conv.participants
        .where((p) => p.id != _currentUserId)
        .firstOrNull;
    return other?.username ?? 'Chat';
  }

  void _openInfo() {
    final conv = widget.conversation;
    if (conv.type == 'group' && conv.groupId != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GroupDetailPage(groupId: conv.groupId!),
      ));
    } else {
      final other = conv.participants
          .where((p) => p.id != _currentUserId)
          .firstOrNull;
      if (other == null) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ClimberProfilePage(
          userId: other.id,
          initialUsername: other.username,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (widget.conversation.type == 'group')
            IconButton(
              icon: const Icon(Icons.support_agent_outlined),
              tooltip: 'Support',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupportPage()),
              ),
            ),
        ],
        title: GestureDetector(
          onTap: _openInfo,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_title()),
                  if (widget.conversation.type == 'group' &&
                      widget.conversation.hasUpcomingEvent) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Upcoming planned climb',
                      child: Icon(Icons.event_outlined,
                          size: 15, color: cs.primary),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
                ],
              ),
              if (_typingUsername != null)
                Text(
                  '$_typingUsername is typing…',
                  style: TextStyle(fontSize: 12, color: cs.primary),
                ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.\nSay hello!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _messages.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (_loadingMore && i == 0) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          }
                          final idx = _loadingMore ? i - 1 : i;
                          final msg = _messages[idx];
                          final isMine = msg.senderId == _currentUserId;
                          final prevMsg = idx > 0 ? _messages[idx - 1] : null;
                          final showSender = !isMine &&
                              (prevMsg == null ||
                                  prevMsg.senderId != msg.senderId);
                          return _MessageBubble(
                            message: msg,
                            isMine: isMine,
                            showSender: showSender,
                          );
                        },
                      ),
          ),
          _InputBar(
            controller: _input,
            sending: _sending,
            onChanged: _onInputChanged,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool showSender;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showSender,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2, top: 6),
              child: Text(
                message.senderUsername,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMine
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(
                          color: isMine
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat.Hm().format(message.createdAt.toLocal()),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine
                              ? cs.onPrimaryContainer.withValues(alpha: 0.6)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: (_) => onSend(),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
