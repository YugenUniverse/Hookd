sealed class Poi {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String description;

  const Poi({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  factory Poi.fromJson(Map<String, dynamic> json) {
    final type = json['poiType']?.toString() ?? '';
    return switch (type) {
      'Facility' => FacilityPoi.fromJson(json),
      _ => OutdoorWallPoi.fromJson(json),
    };
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static ({double lat, double lng}) _parseCoords(Map<String, dynamic> json) {
    final coords = json['location']?['coordinates'];
    if (coords is List && coords.length >= 2) {
      return (lng: _parseDouble(coords[0]), lat: _parseDouble(coords[1]));
    }
    return (lng: 0.0, lat: 0.0);
  }
}

class OutdoorWallPoi extends Poi {
  final String difficulty;
  final double rating;
  final String status;
  final String? ownerName;

  const OutdoorWallPoi({
    required super.id,
    required super.name,
    required super.latitude,
    required super.longitude,
    required super.description,
    required this.difficulty,
    this.rating = 0.0,
    this.status = 'OPEN',
    this.ownerName,
  });

  factory OutdoorWallPoi.fromJson(Map<String, dynamic> json) {
    final coords = Poi._parseCoords(json);
    return OutdoorWallPoi(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Wall').toString(),
      latitude: coords.lat,
      longitude: coords.lng,
      description: (json['description'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? 'UNKNOWN').toString(),
      rating: Poi._parseDouble(json['rating']),
      status: (json['status'] ?? 'OPEN').toString(),
      ownerName: json['ownerName']?.toString(),
    );
  }
}

class IndoorWallSummary {
  final String id;
  final String name;
  final String description;
  final String difficulty;
  final double rating;
  final String status;

  const IndoorWallSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.rating,
    required this.status,
  });

  factory IndoorWallSummary.fromJson(Map<String, dynamic> json) {
    return IndoorWallSummary(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Wall').toString(),
      description: (json['description'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? 'UNKNOWN').toString(),
      rating: Poi._parseDouble(json['rating']),
      status: (json['status'] ?? 'OPEN').toString(),
    );
  }
}

class FacilityPoi extends Poi {
  final List<IndoorWallSummary> walls;
  final String? address;
  final String? ownerAccountId;

  const FacilityPoi({
    required super.id,
    required super.name,
    required super.latitude,
    required super.longitude,
    required super.description,
    required this.walls,
    this.address,
    this.ownerAccountId,
  });

  factory FacilityPoi.fromJson(Map<String, dynamic> json) {
    final coords = Poi._parseCoords(json);
    final wallsRaw = json['walls'];
    final walls = <IndoorWallSummary>[];
    if (wallsRaw is List) {
      for (final w in wallsRaw) {
        if (w is Map<String, dynamic>) {
          walls.add(IndoorWallSummary.fromJson(w));
        } else if (w is Map) {
          walls.add(IndoorWallSummary.fromJson(Map<String, dynamic>.from(w)));
        }
      }
    }
    return FacilityPoi(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Facility').toString(),
      latitude: coords.lat,
      longitude: coords.lng,
      description: (json['description'] ?? '').toString(),
      walls: walls,
      address: json['address']?.toString(),
      ownerAccountId: (json['ownerAccountId'] ?? json['ownerAccount'])?.toString(),
    );
  }
}


class WallAdminSummary {
  final String id;
  final String name;
  final String description;
  final String difficulty;
  final String status;
  final String wallType;

  const WallAdminSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.status,
    required this.wallType,
  });

  factory WallAdminSummary.fromJson(Map<String, dynamic> json) {
    return WallAdminSummary(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Wall').toString(),
      description: (json['description'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? 'UNKNOWN').toString(),
      status: (json['status'] ?? 'OPEN').toString(),
      wallType: (json['wallType'] ?? 'OutdoorWall').toString(),
    );
  }
}
