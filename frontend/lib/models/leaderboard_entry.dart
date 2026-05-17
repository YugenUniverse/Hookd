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
      badges: List<String>.from(json['badges'] ?? []),
    );
  }
}
