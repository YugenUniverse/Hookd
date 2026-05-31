class ClimbingSession {
  final String id;
  final String climberId;
  final String wallId;
  final String? wallName;
  final DateTime date;
  final num time;
  final bool isPrivate;
  final String? reviewId;
  final int? reviewRating;
  final String? reviewBody;

  ClimbingSession({
    required this.id,
    required this.climberId,
    required this.wallId,
    required this.date,
    required this.time,
    this.wallName,
    this.isPrivate = false,
    this.reviewId,
    this.reviewRating,
    this.reviewBody,
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

    // wall_id may be a populated object or a plain id string
    final rawWall = json['wall_id'] ?? json['wallId'];
    final String wallId;
    String? wallName;
    if (rawWall is Map) {
      wallId = (rawWall['id'] ?? rawWall['_id'] ?? '').toString();
      wallName = rawWall['name']?.toString();
    } else {
      wallId = (rawWall ?? '').toString();
    }

    // review_id may be a populated object or a plain id string
    final rawReview = json['review_id'] ?? json['reviewId'];
    String? reviewId;
    int? reviewRating;
    String? reviewBody;
    if (rawReview is Map) {
      reviewId = (rawReview['id'] ?? rawReview['_id'])?.toString();
      final r = rawReview['rating'];
      reviewRating = r is num ? r.toInt() : int.tryParse(r?.toString() ?? '');
      reviewBody = rawReview['body']?.toString();
    } else {
      reviewId = rawReview?.toString();
    }

    return ClimbingSession(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      climberId: (json['climber_id'] ?? json['climberId'] ?? json['userId'] ?? '')
          .toString(),
      wallId: wallId,
      wallName: wallName,
      date: parseDate(json['date']),
      time: parseTime(json['time']),
      isPrivate: parseBool(json['is_private'] ?? json['isPrivate']),
      reviewId: reviewId,
      reviewRating: reviewRating,
      reviewBody: reviewBody,
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
