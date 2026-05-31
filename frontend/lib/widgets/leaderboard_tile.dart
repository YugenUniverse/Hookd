import 'package:flutter/material.dart';
import '../models/leaderboard_entry.dart';
import '../pages/climber_profile_page.dart';

class LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;

  const LeaderboardTile({super.key, required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    Color cardColor;
    Color borderColor;
    double elevation;

    if (rank == 1) {
      cardColor = isDark
          ? Colors.amber.withOpacity(0.15)
          : Colors.amber.shade50;
      borderColor = Colors.amber.shade400;
      elevation = 6; // Highest shadow for the "aura" effect
    } else if (rank == 2) {
      cardColor = isDark
          ? Colors.blueGrey.withOpacity(0.2)
          : Colors.blueGrey.shade50;
      borderColor = Colors.blueGrey.shade300;
      elevation = 4;
    } else if (rank == 3) {
      cardColor = isDark
          ? Colors.deepOrange.withOpacity(0.15)
          : Colors.orange.shade50;
      borderColor = Colors.deepOrange.shade300;
      elevation = 2;
    } else {
      cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
      borderColor = isDark ? Colors.white12 : Colors.transparent;
      elevation = 0;
    }

    return Card(
      elevation: elevation,
      shadowColor: rank == 1 ? Colors.amber.withOpacity(0.4) : null,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: rank <= 3 ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: ListTile(
          onTap: entry.id.isNotEmpty
              ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ClimberProfilePage(
                      userId: entry.id,
                      initialUsername: entry.username,
                    ),
                  ))
              : null,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 35,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: rank <= 3 ? FontWeight.w900 : FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              CircleAvatar(
                backgroundColor: isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade300,
                backgroundImage: entry.avatar.isNotEmpty
                    ? NetworkImage(entry.avatar)
                    : null,
                child: entry.avatar.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ],
          ),

          title: Row(
            children: [
              Expanded(
                child: Text(
                  entry.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18, // Bigger!
                    fontWeight: FontWeight.bold, // Bolder!
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Badges moved next to the name
              if (entry.badges.contains('WALL_MASTER'))
                const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
              if (entry.badges.contains('SPEED_DEMON'))
                const Icon(Icons.bolt, color: Colors.orange, size: 20),
            ],
          ),

          subtitle: Text(
            entry.bestTime != null
                ? 'Best: ${entry.bestTime}m • ${entry.totalAscents} ascents'
                : '${entry.totalAscents} total ascents',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          trailing: Text(
            '${entry.score}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: rank <= 3
                  ? borderColor
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}
