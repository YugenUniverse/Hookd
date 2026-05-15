import 'package:flutter/material.dart';
import '../models/leaderboard_entry.dart';
import 'leaderboard_tile.dart'; // The tile we built earlier

class LeaderboardList extends StatelessWidget {
  final List<LeaderboardEntry> climbers;
  final String emptyMessage;

  const LeaderboardList({
    super.key,
    required this.climbers,
    this.emptyMessage = "No ascents logged yet. Be the first!",
  });

  @override
  Widget build(BuildContext context) {
    if (climbers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Column(
      children: climbers.asMap().entries.map((entry) {
        return LeaderboardTile(entry: entry.value, rank: entry.key + 1);
      }).toList(),
    );
  }
}
