class AppNotification {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.payload,
    required this.read,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};

    return AppNotification(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      payload: payload,
      read: json['read'] == true,
      createdAt: parseDate(json['createdAt']),
    );
  }

  String get eventTitle => payload['eventTitle']?.toString() ?? '';
  String get facilityId => payload['facilityId']?.toString() ?? '';
  String get eventId => payload['eventId']?.toString() ?? '';

  // Issue-specific fields
  String get issueId => payload['issueId']?.toString() ?? '';
  String get wallId => payload['wallId']?.toString() ?? '';
  String get wallName => payload['wallName']?.toString() ?? '';
  String get severity => payload['severity']?.toString() ?? '';
  String get issueBody => payload['body']?.toString() ?? '';
  String get description => payload['description']?.toString() ?? '';
  String get location => payload['location']?.toString() ?? '';
  String get climberId => payload['climberId']?.toString() ?? '';

  // Group invite fields
  String get groupId => payload['groupId']?.toString() ?? '';
  String get groupName => payload['groupName']?.toString() ?? '';
  String get invitationId => payload['invitationId']?.toString() ?? '';
  String get invitedByName => payload['invitedByName']?.toString() ?? '';
}
