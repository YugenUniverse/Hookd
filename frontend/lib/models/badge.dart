class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int score;
  final String type;
  final int level;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.score,
    required this.type,
    required this.level,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      type: (json['type'] ?? 'system').toString(),
      level: (json['level'] as num?)?.toInt() ?? 4,
    );
  }
}

class EarnedBadge {
  final Badge badge;
  final DateTime? earnedAt;

  const EarnedBadge({
    required this.badge,
    this.earnedAt,
  });

  String get formattedDate {
    if (earnedAt == null) return "Unknown";
    return "${earnedAt!.year}-${earnedAt!.month.toString().padLeft(2, '0')}-${earnedAt!.day.toString().padLeft(2, '0')}";
  }

  factory EarnedBadge.fromJson(Map<String, dynamic> json) {
    DateTime? earnedAt;
    final ea = json['earnedAt'];
    if (ea != null) {
      if (ea is String) {
        earnedAt = DateTime.tryParse(ea) ?? DateTime.tryParse(ea.replaceFirst(' ', 'T'));
      } else if (ea is int) {
        earnedAt = DateTime.fromMillisecondsSinceEpoch(ea);
      }
    }

    return EarnedBadge(
      badge: Badge.fromJson(Map<String, dynamic>.from(json['badge'] ?? {})),
      earnedAt: earnedAt,
    );
  }
}

class Wallet {
  final int score;
  final List<EarnedBadge> badges;

  const Wallet({
    required this.score,
    required this.badges,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    final badgesRaw = json['badges'];
    final badges = <EarnedBadge>[];
    if (badgesRaw is List) {
      for (final b in badgesRaw) {
        if (b is Map) {
          badges.add(EarnedBadge.fromJson(Map<String, dynamic>.from(b)));
        }
      }
    }

    return Wallet(
      score: (json['score'] as num?)?.toInt() ?? 0,
      badges: badges,
    );
  }
}
