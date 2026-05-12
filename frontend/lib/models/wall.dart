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
    };
  }
}
