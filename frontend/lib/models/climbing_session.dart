class ClimbingSession {
  final String id;
  final String climberId;
  final String wallId;
  final DateTime date;
  final num time;
  final bool isPrivate;
  final String? reviewId;

  ClimbingSession({
    required this.id,
    required this.climberId,
    required this.wallId,
    required this.date,
    required this.time,
    this.isPrivate = false,
    this.reviewId,
  });

  factory ClimbingSession.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    num parseTime(dynamic value) {
      if (value is num) return value;
      if (value is String) return num.tryParse(value) ?? 0;
      return 0;
    }

    bool parseBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value.toString().toLowerCase();
      return text == '1' || text == 'true' || text == 'yes';
    }

    return ClimbingSession(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      climberId: (json['climber_id'] ?? json['climberId'] ?? json['userId'] ?? '')
          .toString(),
      wallId: (json['wall_id'] ?? json['wallId'] ?? '').toString(),
      date: parseDate(json['date']),
      time: parseTime(json['time']),
      isPrivate: parseBool(json['is_private'] ?? json['isPrivate']),
      reviewId: (json['review_id'] ?? json['reviewId'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'climber_id': climberId,
      'wall_id': wallId,
      'date': date.toIso8601String(),
      'time': time,
      'is_private': isPrivate,
      'review_id': reviewId,
    };
  }
}
