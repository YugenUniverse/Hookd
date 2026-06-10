class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderUsername;
  final String? senderAvatar;
  final String content;
  final DateTime createdAt;
  final List<Map<String, dynamic>> readBy;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderUsername,
    this.senderAvatar,
    required this.content,
    required this.createdAt,
    this.readBy = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    String senderId = '';
    String senderUsername = '';
    String? senderAvatar;

    if (sender is Map) {
      senderId = sender['id']?.toString() ?? sender['_id']?.toString() ?? '';
      senderUsername = sender['username']?.toString() ?? '';
      senderAvatar = sender['avatar']?.toString();
    } else {
      senderId = sender?.toString() ?? '';
    }

    return ChatMessage(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      conversationId: json['conversation']?.toString() ?? '',
      senderId: senderId,
      senderUsername: senderUsername,
      senderAvatar: senderAvatar,
      content: json['content']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']),
      readBy: (json['readBy'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now();
  }
}
