class Review {
  final String id;
  final int rating;
  final String body;
  final String reviewerId;
  final String reviewerName;
  final String wallId;
  final String wallName;
  final DateTime? sessionDate;
  final int sessionTimeMinutes;
  final bool sessionIsPrivate;
  final bool flagged;
  final String flagReason;

  Review({
    required this.id,
    required this.rating,
    required this.body,
    required this.reviewerId,
    required this.reviewerName,
    required this.wallId,
    required this.wallName,
    required this.sessionDate,
    required this.sessionTimeMinutes,
    required this.sessionIsPrivate,
    this.flagged = false,
    this.flagReason = '',
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final session = _asMap(json['climbing_session_id']);
    final wall = _asMap(session?['wall_id']);
    final climber = _asMap(session?['climber_id']);

    return Review(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      rating: _toInt(json['rating']),
      body: (json['body'] ?? '').toString(),
      reviewerId: _pickId(climber),
      reviewerName: _pickName(climber),
      wallId: _pickId(wall),
      wallName: _pickName(wall),
      sessionDate: _parseDate(session?['date']),
      sessionTimeMinutes: _toInt(session?['time']),
      sessionIsPrivate: _toBool(session?['is_private']),
      flagged: _toBool(json['flagged']),
      flagReason: (json['flagReason'] ?? '').toString(),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String _pickId(Map<String, dynamic>? value) {
    if (value == null) return '';
    return (value['id'] ?? value['_id'] ?? '').toString();
  }

  static String _pickName(Map<String, dynamic>? value) {
    if (value == null) return 'Unknown';
    return (value['username'] ?? value['name'] ?? value['email'] ?? 'Unknown')
        .toString();
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.tryParse(value.replaceFirst(' ', 'T'));
    }
    return null;
  }
}
