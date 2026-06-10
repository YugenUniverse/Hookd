class GroupMember {
  final String userId;
  final String? username;
  final String? name;
  final String role;
  final int score;
  final DateTime? joinedAt;

  const GroupMember({
    required this.userId,
    required this.role,
    this.score = 0,
    this.username,
    this.name,
    this.joinedAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager' || role == 'admin';

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    String userId;
    String? username;
    String? name;
    if (userRaw is Map) {
      userId = (userRaw['id'] ?? userRaw['_id'] ?? '').toString();
      username = userRaw['username']?.toString();
      name = userRaw['name']?.toString();
    } else {
      userId = (userRaw ?? '').toString();
    }

    DateTime? joinedAt;
    final ja = json['joinedAt'];
    if (ja is String) joinedAt = DateTime.tryParse(ja);

    return GroupMember(
      userId: userId,
      username: username,
      name: name,
      role: (json['role'] ?? 'member').toString(),
      score: (json['score'] ?? 0) as int,
      joinedAt: joinedAt,
    );
  }
}

class Group {
  final String id;
  final String name;
  final String? description;
  final String visibility; // "public" or "private"
  final String creatorId;
  final List<GroupMember> members;
  final int? memberCount; // only set in discover results (no member list populated)
  final DateTime? createdAt;
  final bool hasUpcomingEvent;

  const Group({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.members,
    this.description,
    this.visibility = 'private',
    this.memberCount,
    this.createdAt,
    this.hasUpcomingEvent = false,
  });

  bool get isPublic => visibility == 'public';

  factory Group.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['members'];
    final members = <GroupMember>[];
    if (membersRaw is List) {
      for (final m in membersRaw) {
        if (m is Map) members.add(GroupMember.fromJson(Map<String, dynamic>.from(m)));
      }
    }

    DateTime? createdAt;
    final ca = json['createdAt'];
    if (ca is String) createdAt = DateTime.tryParse(ca);

    final creatorRaw = json['creator'];
    final creatorId = creatorRaw is Map
        ? (creatorRaw['id'] ?? creatorRaw['_id'] ?? '').toString()
        : (creatorRaw ?? '').toString();

    return Group(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      visibility: (json['visibility'] ?? 'private').toString(),
      creatorId: creatorId,
      members: members,
      memberCount: json['memberCount'] as int?,
      createdAt: createdAt,
      hasUpcomingEvent: json['hasUpcomingEvent'] == true,
    );
  }
}

class ClimbAttendee {
  final String userId;
  final String? username;
  final String? name;
  final String status; // "going" or "not_going"

  const ClimbAttendee({
    required this.userId,
    required this.status,
    this.username,
    this.name,
  });

  factory ClimbAttendee.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    String userId;
    String? username;
    String? name;
    if (userRaw is Map) {
      userId = (userRaw['id'] ?? userRaw['_id'] ?? '').toString();
      username = userRaw['username']?.toString();
      name = userRaw['name']?.toString();
    } else {
      userId = (userRaw ?? '').toString();
    }
    return ClimbAttendee(
      userId: userId,
      username: username,
      name: name,
      status: (json['status'] ?? '').toString(),
    );
  }
}

class PlannedClimb {
  final String id;
  final String groupId;
  final DateTime date;
  final String? wallName;
  final String? venueId;
  final String? venueType; // "Wall" or "Facility"
  final String? notes;
  final String? createdByName;
  final String? createdByUsername;
  final List<ClimbAttendee> attendees;

  const PlannedClimb({
    required this.id,
    required this.groupId,
    required this.date,
    required this.attendees,
    this.wallName,
    this.venueId,
    this.venueType,
    this.notes,
    this.createdByName,
    this.createdByUsername,
  });

  factory PlannedClimb.fromJson(Map<String, dynamic> json) {
    final createdByRaw = json['createdBy'];
    String? createdByName;
    String? createdByUsername;
    if (createdByRaw is Map) {
      createdByName = createdByRaw['name']?.toString();
      createdByUsername = createdByRaw['username']?.toString();
    }

    String? venueId;
    String? venueType;
    final wallRaw = json['wall'];
    final facilityRaw = json['facility'];
    if (wallRaw is Map) {
      venueId = (wallRaw['id'] ?? wallRaw['_id'])?.toString();
      venueType = 'Wall';
    } else if (wallRaw is String && wallRaw.isNotEmpty) {
      venueId = wallRaw;
      venueType = 'Wall';
    } else if (facilityRaw is Map) {
      venueId = (facilityRaw['id'] ?? facilityRaw['_id'])?.toString();
      venueType = 'Facility';
    } else if (facilityRaw is String && facilityRaw.isNotEmpty) {
      venueId = facilityRaw;
      venueType = 'Facility';
    }

    final attendeesRaw = json['attendees'];
    final attendees = <ClimbAttendee>[];
    if (attendeesRaw is List) {
      for (final a in attendeesRaw) {
        if (a is Map) attendees.add(ClimbAttendee.fromJson(Map<String, dynamic>.from(a)));
      }
    }

    return PlannedClimb(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      groupId: (json['group'] ?? '').toString(),
      date: DateTime.parse(json['date'].toString()),
      wallName: json['wallName']?.toString(),
      venueId: venueId,
      venueType: venueType,
      notes: json['notes']?.toString(),
      createdByName: createdByName,
      createdByUsername: createdByUsername,
      attendees: attendees,
    );
  }
}

class GroupInvitation {
  final String id;
  final String groupId;
  final String groupName;
  final String? groupDescription;
  final String invitedById;
  final String? invitedByUsername;
  final String? invitedByName;
  final String status;
  final DateTime? createdAt;

  const GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.invitedById,
    required this.status,
    this.groupDescription,
    this.invitedByUsername,
    this.invitedByName,
    this.createdAt,
  });

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    final groupRaw = json['group'];
    String groupId;
    String groupName;
    String? groupDescription;
    if (groupRaw is Map) {
      groupId = (groupRaw['id'] ?? groupRaw['_id'] ?? '').toString();
      groupName = (groupRaw['name'] ?? '').toString();
      groupDescription = groupRaw['description']?.toString();
    } else {
      groupId = (groupRaw ?? '').toString();
      groupName = '';
    }

    final invitedByRaw = json['invitedBy'];
    String invitedById;
    String? invitedByUsername;
    String? invitedByName;
    if (invitedByRaw is Map) {
      invitedById = (invitedByRaw['id'] ?? invitedByRaw['_id'] ?? '').toString();
      invitedByUsername = invitedByRaw['username']?.toString();
      invitedByName = invitedByRaw['name']?.toString();
    } else {
      invitedById = (invitedByRaw ?? '').toString();
    }

    DateTime? createdAt;
    final ca = json['createdAt'];
    if (ca is String) createdAt = DateTime.tryParse(ca);

    return GroupInvitation(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      groupId: groupId,
      groupName: groupName,
      groupDescription: groupDescription,
      invitedById: invitedById,
      invitedByUsername: invitedByUsername,
      invitedByName: invitedByName,
      status: (json['status'] ?? 'pending').toString(),
      createdAt: createdAt,
    );
  }
}
