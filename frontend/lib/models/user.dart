import 'poi.dart' show IndoorWallSummary;

class PublicBodyData {
  final String name;
  final String description;
  final String? address;
  final List<double>? coordinates;
  final List<IndoorWallSummary> walls;

  const PublicBodyData({
    required this.name,
    required this.description,
    required this.walls,
    this.address,
    this.coordinates,
  });

  factory PublicBodyData.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    String? address;
    List<double>? coordinates;
    if (location is Map) address = location['address']?.toString();
    if (location is Map && location['coordinates'] is List) {
      final raw = location['coordinates'] as List;
      if (raw.length == 2) {
        final lng = raw[0];
        final lat = raw[1];
        final parsedLng = lng is num ? lng.toDouble() : double.tryParse(lng.toString());
        final parsedLat = lat is num ? lat.toDouble() : double.tryParse(lat.toString());
        if (parsedLng != null && parsedLat != null) {
          coordinates = [parsedLng, parsedLat];
        }
      }
    }

    final wallsRaw = json['walls'];
    final walls = <IndoorWallSummary>[];
    if (wallsRaw is List) {
      for (final w in wallsRaw) {
        if (w is Map) {
          walls.add(IndoorWallSummary.fromJson(Map<String, dynamic>.from(w)));
        }
      }
    }

    return PublicBodyData(
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      address: address,
      coordinates: coordinates,
      walls: walls,
    );
  }
}

class FacilityProfile {
  final String id;
  final String name;
  final String description;
  final String? address;
  final List<double>? coordinates;
  final List<IndoorWallSummary> walls;

  const FacilityProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.walls,
    this.address,
    this.coordinates,
  });

  factory FacilityProfile.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    String? address;
    List<double>? coordinates;
    if (location is Map) address = location['address']?.toString();
    if (location is Map && location['coordinates'] is List) {
      final rawCoordinates = location['coordinates'] as List;
      if (rawCoordinates.length == 2) {
        final lng = rawCoordinates[0];
        final lat = rawCoordinates[1];
        final parsedLng = lng is num ? lng.toDouble() : double.tryParse(lng.toString());
        final parsedLat = lat is num ? lat.toDouble() : double.tryParse(lat.toString());
        if (parsedLng != null && parsedLat != null) {
          coordinates = [parsedLng, parsedLat];
        }
      }
    }

    final wallsRaw = json['walls'];
    final walls = <IndoorWallSummary>[];
    if (wallsRaw is List) {
      for (final w in wallsRaw) {
        if (w is Map) {
          walls.add(IndoorWallSummary.fromJson(Map<String, dynamic>.from(w)));
        }
      }
    }

    return FacilityProfile(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      address: address,
      coordinates: coordinates,
      walls: walls,
    );
  }
}

class User {
  final String id;
  final String username;
  final String email;
  final String? profilePictureUrl;
  final DateTime? createdAt;
  final bool isAdmin;
  final bool originalMember;
  final String? userType;
  final FacilityProfile? facilityData;
  final PublicBodyData? publicBodyData;
  final String? name;
  final String? surname;
  final String? bio;
  final DateTime? birthdate;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.profilePictureUrl,
    this.createdAt,
    this.isAdmin = false,
    this.originalMember = false,
    this.userType,
    this.facilityData,
    this.publicBodyData,
    this.name,
    this.surname,
    this.bio,
    this.birthdate,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String stringize(dynamic v) => v == null ? '' : v.toString();

    final id = stringize(json['id'] ?? json['user_id'] ?? json['email'] ?? '');
    final username = stringize(json['username'] ?? json['user'] ?? '');
    final email = stringize(json['email'] ?? '');

    String? profilePictureUrl;
    if (json['profile_picture_url'] != null) {
      profilePictureUrl = stringize(json['profile_picture_url']);
    } else if (json['avatar'] != null) {
      profilePictureUrl = stringize(json['avatar']);
    }

    DateTime? createdAt;
    final ca = json['created_at'] ?? json['createdAt'];
    if (ca != null) {
      if (ca is String) {
        createdAt =
            DateTime.tryParse(ca) ??
            DateTime.tryParse(ca.replaceFirst(' ', 'T'));
      } else if (ca is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(ca);
      }
    }

    bool parseBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }

    final isAdmin = parseBool(
      json['is_admin'] ?? json['isAdmin'] ?? json['admin'],
    );
    final originalMember = parseBool(
      json['original_fiatlinux'] ?? json['originalMember'] ?? json['original'],
    );

    final userType = json['userType']?.toString();

    FacilityProfile? facilityData;
    final facilityRaw = json['facility'];
    if (facilityRaw is Map) {
      facilityData =
          FacilityProfile.fromJson(Map<String, dynamic>.from(facilityRaw));
    }

    PublicBodyData? publicBodyData;
    if (userType == 'PublicBody') {
      publicBodyData = PublicBodyData.fromJson(json);
    }

    final name = json['name']?.toString();
    final surname = json['surname']?.toString();
    final bio = json['bio']?.toString();

    DateTime? birthdate;
    final bd = json['birthdate'];
    if (bd != null) {
      if (bd is String) {
        birthdate = DateTime.tryParse(bd);
      } else if (bd is int) {
        birthdate = DateTime.fromMillisecondsSinceEpoch(bd);
      }
    }

    return User(
      id: id,
      username: username,
      email: email,
      profilePictureUrl: profilePictureUrl,
      createdAt: createdAt,
      isAdmin: isAdmin,
      originalMember: originalMember,
      userType: userType,
      facilityData: facilityData,
      publicBodyData: publicBodyData,
      name: name,
      surname: surname,
      bio: bio,
      birthdate: birthdate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'profile_picture_url': profilePictureUrl,
      'created_at': createdAt?.toIso8601String(),
      'is_admin': isAdmin ? 1 : 0,
      'original_fiatlinux': originalMember ? 1 : 0,
    };
  }
}
