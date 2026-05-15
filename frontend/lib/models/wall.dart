import 'climbing_session.dart';

class Wall {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String description;
  final String difficulty;
  final String wallType;
  final String? ownerName;
  final List<ClimbingSession> sessions;
  final double rating;
  final int totalSessions;

  Wall({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.difficulty,
    required this.wallType,
    this.ownerName,
    required this.sessions,
    this.rating = 0.0,
    this.totalSessions = 0,
  });

  // Compatibility with older UI code that expects `type`.
  String get type => wallType;

  factory Wall.fromJson(Map<String, dynamic> json) {
    final coordinates = json['location']?['coordinates'];
    double latitude = _parseDouble(json['latitude']);
    double longitude = _parseDouble(json['longitude']);

    if (coordinates is List && coordinates.length >= 2) {
      longitude = _parseDouble(coordinates[0]);
      latitude = _parseDouble(coordinates[1]);
    }

    final wallType = (json['wallType'] ?? json['type'] ?? 'Wall').toString();

    String? owner;
    if (json['facility'] is Map) {
      owner = json['facility']['username']?.toString();
    } else if (json['publicBody'] is Map) {
      owner = json['publicBody']['username']?.toString();
    }

    final sessionsRaw = json['sessions'];
    final sessions = <ClimbingSession>[];
    if (sessionsRaw is List) {
      for (final item in sessionsRaw) {
        if (item is Map<String, dynamic>) {
          sessions.add(ClimbingSession.fromJson(item));
        } else if (item is Map) {
          sessions.add(ClimbingSession.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    double parseRating(dynamic r) {
      if (r == null) return 0.0;
      if (r is num) return r.toDouble();
      if (r is String) return double.tryParse(r) ?? 0.0;
      return 0.0;
    }

    int parseTotalSessions(dynamic s) {
      if (s == null) return 0;
      if (s is int) return s;
      if (s is num) return s.toInt();
      if (s is String) return int.tryParse(s) ?? 0;
      return 0;
    }

    final rating = parseRating(json['rating']);
    final totalSessions = parseTotalSessions(json['totalSessions'] ?? json['total_sessions']);

    return Wall(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Wall').toString(),
      latitude: latitude,
      longitude: longitude,
      description: (json['description'] ?? 'No description available.').toString(),
      difficulty: (json['difficulty'] ?? 'UNKNOWN').toString(),
      wallType: wallType,
      ownerName: owner,
      sessions: sessions,
      rating: rating,
      totalSessions: totalSessions,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'difficulty': difficulty,
      'wallType': wallType,
      'ownerName': ownerName,
      'sessions': sessions.map((session) => session.toJson()).toList(),
      'rating': rating,
      'totalSessions': totalSessions,
    };
  }
}
