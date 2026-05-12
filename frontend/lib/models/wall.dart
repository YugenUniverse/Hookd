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
}

  Wall({
    required this.id,
    required this.name,
    required this.latitude;
    required this.longitude;
    required this.description,
    required this.difficulty,
    required this.wallType,
    this.ownerName,
    required this.sessions,
  });

  factory Wall.fromJson(Map<String, dynamic> json) {
    try {
      // Try to parse from GeoJSON location format
      if (json['location'] != null && json['location']['coordinates'] != null) {
        final coords = json['location']['coordinates'] as List;
        if (coords.length >= 2) {
          longitude = _parseDouble(coords[0]);
          latitude = _parseDouble(coords[1]);
        }
      } else {
        // Fallback to direct latitude/longitude fields
        latitude = _parseDouble(json['latitude']);
        longitude = _parseDouble(json['longitude']);
      }
    } catch (e) {
      print('Error parsing coordinates for wall: $e');
    }
    
    String? owner;
    if (json['wallType'] == 'IndoorWall' && json['facility'] != null) {
      owner = json['facility']['username'];
    } else if (json['wallType'] == 'OutdoorWall' &&
        json['publicBody'] != null) {
      owner = json['publicBody']['username'];
    }

    var sessionsList = json['sessions'] as List? ?? [];
    List<ClimbingSession> parsedSessions = sessionsList
        .map((sessionJson) => ClimbingSession.fromJson(sessionJson))
        .toList();

    return Wall(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Wall',
      latitude: latitude,
      longitude: longitude,
      description: json['description'] ?? 'No description available.',
      difficulty: json['difficulty'] ?? 'BEGINNER',
      wallType: json['wallType'] ?? 'Wall',
      ownerName: owner ?? 'Unknown Owner',
      sessions: parsedSessions,
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
      '_id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'wallType': wallType,
      'ownerName': ownerName,
      'difficulty': difficulty,
    };
  }
}
