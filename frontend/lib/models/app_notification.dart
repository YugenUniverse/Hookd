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
}
