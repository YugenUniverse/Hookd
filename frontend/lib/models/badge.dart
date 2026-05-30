import 'package:flutter/material.dart';

class WinningCondition {
  final String metric;
  final String operator;
  final int value;

  const WinningCondition({
    required this.metric,
    required this.operator,
    required this.value,
  });

  factory WinningCondition.fromJson(Map<String, dynamic> json) {
    return WinningCondition(
      metric: (json['metric'] ?? '').toString(),
      operator: (json['operator'] ?? '').toString(),
      value: (json['value'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metric': metric,
      'operator': operator,
      'value': value,
    };
  }
}

class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int score;
  final String type;
  final int level;
  final String? eventId;
  final WinningCondition? winningCondition;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.score,
    required this.type,
    required this.level,
    this.eventId,
    this.winningCondition,
  });

  Color get badgeColor {
    switch (level) {
      case 1:
        return Colors.amber; // Gold
      case 2:
        return Colors.blueGrey.shade300; // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.blue; // Standard
    }
  }

  IconData get badgeIcon {
    if (icon == 'trophy') return Icons.emoji_events;
    if (icon == 'medal') return Icons.workspace_premium;
    if (icon == 'star') return Icons.star;
    if (icon == 'flash') return Icons.flash_on;
    if (icon == 'mountain') return Icons.terrain;
    return Icons.emoji_events;
  }

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      type: (json['type'] ?? 'system').toString(),
      level: (json['level'] as num?)?.toInt() ?? 4,
      eventId: json['eventId']?.toString(),
      winningCondition: json['winningCondition'] != null
          ? WinningCondition.fromJson(
              Map<String, dynamic>.from(json['winningCondition']))
          : null,
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
