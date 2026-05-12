class ClimbingSession {
  final String id;
  final String userId;
  final String date;
  final int? durationInMinutes;
  final int? rating;
  final String? notes;

  ClimbingSession({
    required this.id,
    required this.userId,
    required this.date,
    this.durationInMinutes,
    this.rating,
    this.notes,
  });

  factory ClimbingSession.fromJson(Map<String, dynamic> json) {
    return ClimbingSession(
      id: json['id'] ?? json['_id'] ?? '',

      userId: json['user'] is Map ? json['user']['id'] : json['user'] ?? '',

      date: json['date'] ?? '',
      durationInMinutes: json['durationInMinutes'],
      rating: json['rating'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date,
      'durationInMinutes': durationInMinutes,
      'rating': rating,
      'notes': notes,
    };
  }
}
