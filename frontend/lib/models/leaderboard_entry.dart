class LeaderboardEntry {
  final String id;
  final String username;
  final String avatar;
  final int totalAscents;
  final int? bestTime;
  final int score;
  final List<String> badges;

  LeaderboardEntry({
    required this.id,
    required this.username,
    required this.avatar,
    required this.totalAscents,
    this.bestTime,
    required this.score,
    required this.badges,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      id: json['id'] ?? '',
      username: json['username'] ?? 'Unknown Climber',
      avatar: json['avatar'] ?? '',
      totalAscents: json['totalAscents'] ?? 0,
      bestTime: json['bestTime'],
      score: json['score'] ?? 0,
      badges: (json['badges'] as List<dynamic>?)?.map((b) {
        if (b is String) return b;
        if (b is Map) {
          final badgeObj = b['badge'];
          if (badgeObj is String) return badgeObj;
          if (badgeObj is Map && badgeObj['name'] != null) return badgeObj['name'] as String;
        }
        return '';
      }).where((s) => s.isNotEmpty).toList() ?? [],
    );
  }
}
