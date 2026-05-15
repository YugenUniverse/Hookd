import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../pages/log_session_page.dart';
import '../models/wall.dart';
import '../models/leaderboard_entry.dart';
import '../widgets/leaderboard_list.dart';

class WallDetailsDialog extends StatelessWidget {
  final Wall wall;

  const WallDetailsDialog({super.key, required this.wall});

  @override
  Widget build(BuildContext context) {
    final bool isIndoor = wall.wallType == 'IndoorWall';
    final IconData typeIcon = isIndoor ? Icons.domain : Icons.landscape;
    final Color typeColor = isIndoor ? Colors.blueGrey : Colors.green;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(typeIcon, color: typeColor, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      wall.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Log session',
                    onPressed: () {
                      final rootContext = Navigator.of(
                        context,
                        rootNavigator: true,
                      ).context;
                      Navigator.of(context).pop();
                      showModalBottomSheet(
                        context: rootContext,
                        isScrollControlled: true,
                        useSafeArea: true,
                        showDragHandle: true,
                        builder: (_) => LogSessionPage(initialWall: wall),
                      );
                    },
                    icon: const Icon(Icons.edit_calendar_outlined),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip(
                        label: Text(
                          isIndoor ? 'Indoor Facility' : 'Outdoor Crag',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: typeColor,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        context,
                        Icons.fitness_center,
                        'Difficulty',
                        wall.difficulty,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        isIndoor ? Icons.business : Icons.account_balance,
                        'Managed By',
                        wall.ownerName ?? 'Unknown',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        Icons.history,
                        'Total Climbs',
                        '${wall.sessions.length} sessions logged',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        wall.description,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),

                      // --- THE LEADERBOARD WIDGET ---
                      WallLeaderboardSection(wallId: wall.id),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    final iconColor = Theme.of(context).iconTheme.color ?? Colors.grey;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: textColor, fontSize: 14),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WallLeaderboardSection extends StatefulWidget {
  final String wallId;

  const WallLeaderboardSection({super.key, required this.wallId});

  @override
  State<WallLeaderboardSection> createState() => _WallLeaderboardSectionState();
}

class _WallLeaderboardSectionState extends State<WallLeaderboardSection> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  int _offset = 0;

  final String baseUrl = 'http://localhost:3000';

  Future<Map<String, dynamic>> _fetchLeaderboard() async {
    String? token = await _storage.read(key: 'jwt_token');

    final response = await http.get(
      Uri.parse('$baseUrl/walls/${widget.wallId}/leaderboard?offset=$_offset'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // Map the raw JSON into your strongly typed Dart models
      final List<dynamic> rawList = decoded['leaderboard'] ?? [];
      final List<LeaderboardEntry> climbers = rawList
          .map((json) => LeaderboardEntry.fromJson(json))
          .toList();

      return {
        'seasonName': decoded['seasonName'],
        'isHistorical': decoded['isHistorical'],
        'daysRemaining': decoded['daysRemaining'],
        'averageTime': decoded['averageTime'],
        'leaderboard': climbers,
      };
    } else {
      throw Exception('Failed to load leaderboard');
    }
  }

  void _changeSeason(int delta) {
    setState(() {
      // Prevent going into the future (offset > 0)
      if (_offset + delta <= 0) {
        _offset += delta;
      }
    });
  }

  Color _getDaysLeftColor(int days) {
    if (days >= 45) return Colors.greenAccent.shade400;
    if (days >= 15) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchLeaderboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Error loading leaderboard."));
        }

        final data = snapshot.data!;
        final List<LeaderboardEntry> climbers = data['leaderboard'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: () => _changeSeason(-1),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        data['seasonName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!data['isHistorical'])
                        Text(
                          '${data['daysRemaining']} days left',
                          style: TextStyle(
                            color: _getDaysLeftColor(
                              data['daysRemaining'],
                            ), // 👈 Dynamic color here!
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        const Text(
                          '🏆 Final Results',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: _offset < 0 ? () => _changeSeason(1) : null,
                ),
              ],
            ),

            if (data['averageTime'] > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🎯 Community Average: ${data['averageTime']} mins',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            LeaderboardList(
              climbers: climbers,
              emptyMessage: "No ascents logged this season. Be the first!",
            ),
          ],
        );
      },
    );
  }
}
