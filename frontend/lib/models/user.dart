class User {
  final String id;
  final String username;
  final String email;
  final String? profilePictureUrl;
  final DateTime? createdAt;
  final bool isAdmin;
  final bool originalMember;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.profilePictureUrl,
    this.createdAt,
    this.isAdmin = false,
    this.originalMember = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String stringize(dynamic v) => v == null ? '' : v.toString();

    // id fallback: id, user_id, email (email as fallback id)
    final id = stringize(json['id'] ?? json['user_id'] ?? json['email'] ?? '');

    final username = stringize(json['username'] ?? json['user'] ?? '');
    final email = stringize(json['email'] ?? '');

    String? profilePictureUrl;
    if (json['profile_picture_url'] != null) {
      profilePictureUrl = stringize(json['profile_picture_url']);
    } else if (json['avatar'] != null)
      profilePictureUrl = stringize(json['avatar']);

    DateTime? createdAt;
    final ca = json['created_at'] ?? json['createdAt'];
    if (ca != null) {
      if (ca is String) {
        // try parse; some APIs return "YYYY-MM-DD HH:MM:SS"
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

    return User(
      id: id,
      username: username,
      email: email,
      profilePictureUrl: profilePictureUrl,
      createdAt: createdAt,
      isAdmin: isAdmin,
      originalMember: originalMember,
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
