import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/api_config.dart';
import '../models/message.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ChatService extends ChangeNotifier {
  static final ChatService _i = ChatService._internal();
  factory ChatService() => _i;
  ChatService._internal();

  io.Socket? _socket;

  // Stream controllers for real-time events
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _readController = StreamController<Map<String, dynamic>>.broadcast();
  final _joinedController = StreamController<String>.broadcast();

  Stream<ChatMessage> get onNewMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onRead => _readController.stream;
  /// Fires the conversationId whenever the user opens a conversation.
  Stream<String> get onConversationJoined => _joinedController.stream;

  bool get isConnected => _socket?.connected == true;

  void connect() {
    final token = AuthService().jwt;
    if (token == null) return;

    final wsUrl = ApiConfig.apiBaseUrl;

    _socket = io.io(
      wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('ChatService: connected');
      _joinAllConversations();
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      debugPrint('ChatService: disconnected');
      notifyListeners();
    });

    _socket!.on('new_message', (data) {
      try {
        final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data as Map));
        _messageController.add(msg);
      } catch (e) {
        debugPrint('ChatService: failed to parse new_message: $e');
      }
    });

    _socket!.on('user_typing', (data) {
      _typingController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('user_stop_typing', (data) {
      _typingController.add({
        ...Map<String, dynamic>.from(data as Map),
        'stopped': true,
      });
    });

    _socket!.on('messages_read', (data) {
      _readController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    notifyListeners();
  }

  Future<void> _joinAllConversations() async {
    try {
      final conversations = await ApiService().getConversations();
      for (final conv in conversations) {
        _socket?.emit('join_conversation', conv.id);
      }
    } catch (e) {
      debugPrint('ChatService: failed to auto-join conversations: $e');
    }
  }

  void joinConversation(String conversationId) {
    _socket?.emit('join_conversation', conversationId);
    _joinedController.add(conversationId);
  }

  void leaveConversation(String conversationId) {
    _socket?.emit('leave_conversation', conversationId);
  }

  // Returns the sent message via ack callback
  Future<ChatMessage?> sendMessage(
      String conversationId, String content) async {
    if (_socket == null || !isConnected) return null;

    final completer = Completer<ChatMessage?>();

    _socket!.emitWithAck(
      'send_message',
      {'conversationId': conversationId, 'content': content},
      ack: (data) {
        try {
          final map = data is Map ? Map<String, dynamic>.from(data) : null;
          if (map != null && map['ok'] == true && map['message'] is Map) {
            completer.complete(
                ChatMessage.fromJson(Map<String, dynamic>.from(map['message'] as Map)));
          } else {
            completer.complete(null);
          }
        } catch (_) {
          completer.complete(null);
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 10),
        onTimeout: () => null);
  }

  void emitTyping(String conversationId) {
    _socket?.emit('typing', {'conversationId': conversationId});
  }

  void emitStopTyping(String conversationId) {
    _socket?.emit('stop_typing', {'conversationId': conversationId});
  }

  void markRead(String conversationId) {
    _socket?.emit('mark_read', {'conversationId': conversationId});
  }

  @override
  void dispose() {
    _messageController.close();
    _typingController.close();
    _readController.close();
    _joinedController.close();
    disconnect();
    super.dispose();
  }
}
