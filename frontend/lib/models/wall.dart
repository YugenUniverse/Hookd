class Wall {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? description;
  final String? type;
  final String? difficulty;

  Wall({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
    this.type,
    this.difficulty,
  });

  factory Wall.fromJson(Map<String, dynamic> json) {
    double latitude = 0;
    double longitude = 0;
    
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
    
    return Wall(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      latitude: latitude,
      longitude: longitude,
      description: json['description'],
      type: json['type'],
      difficulty: json['difficulty'],
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
      'type': type,
      'difficulty': difficulty,
    };
  }
}
