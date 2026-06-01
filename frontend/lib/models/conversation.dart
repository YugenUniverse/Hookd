import 'message.dart';

class Conversation {
  final String id;
  final String type; // 'dm' | 'group'
  final List<ConversationParticipant> participants;
  final String? groupId;
  final String? groupName;
  final ChatMessage? lastMessage;
  final DateTime lastActivity;
  final bool hasUnread;
  final bool hasUpcomingEvent;

  Conversation({
    required this.id,
    required this.type,
    required this.participants,
    this.groupId,
    this.groupName,
    this.lastMessage,
    required this.lastActivity,
    this.hasUnread = false,
    this.hasUpcomingEvent = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final group = json['group'];

    return Conversation(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'dm',
      participants: (json['participants'] as List?)
              ?.map((p) => ConversationParticipant.fromJson(
                  Map<String, dynamic>.from(p as Map)))
              .toList() ??
          [],
      groupId: group is Map
          ? group['id']?.toString() ?? group['_id']?.toString()
          : group?.toString(),
      groupName: group is Map ? group['name']?.toString() : null,
      lastMessage: json['lastMessage'] is Map
          ? ChatMessage.fromJson(
              Map<String, dynamic>.from(json['lastMessage'] as Map))
          : null,
      lastActivity: _parseDate(json['lastActivity'] ?? json['updatedAt']),
      hasUnread: json['hasUnread'] == true,
      hasUpcomingEvent: json['hasUpcomingEvent'] == true,
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now();
  }

  Conversation copyWith({ChatMessage? lastMessage, bool? hasUnread, DateTime? lastActivity}) {
    return Conversation(
      id: id,
      type: type,
      participants: participants,
      groupId: groupId,
      groupName: groupName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastActivity: lastActivity ?? this.lastActivity,
      hasUnread: hasUnread ?? this.hasUnread,
      hasUpcomingEvent: hasUpcomingEvent,
    );
  }

  // Returns a display name for the conversation from the perspective of [currentUserId]
  String displayName(String currentUserId) {
    if (type == 'group') return groupName ?? 'Group';
    final other = participants.where((p) => p.id != currentUserId).firstOrNull;
    return other?.username ?? 'Unknown';
  }
}

class ConversationParticipant {
  final String id;
  final String username;
  final String? avatar;

  ConversationParticipant({
    required this.id,
    required this.username,
    this.avatar,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) {
    return ConversationParticipant(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
    );
  }
}
