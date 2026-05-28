import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/badge.dart' as model;
import '../services/api_service.dart';

class EventLeaderboardPage extends StatefulWidget {
  final Event event;

  const EventLeaderboardPage({Key? key, required this.event}) : super(key: key);

  @override
  State<EventLeaderboardPage> createState() => _EventLeaderboardPageState();
}

class _EventLeaderboardPageState extends State<EventLeaderboardPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final leaderboard =
          await ApiService().getEventLeaderboard(widget.event.id);
      setState(() {
        _leaderboard = leaderboard;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.event.title} - Leaderboard'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading leaderboard',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchLeaderboard();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_leaderboard.isEmpty) {
      return const Center(
        child: Text('No climbers have participated yet.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _leaderboard.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final entry = _leaderboard[index];
        final rank = entry['rank'] as int? ?? (index + 1);
        final score = entry['score'] as int? ?? 0;
        final sessions = entry['sessions'] as int? ?? 0;
        final climberName = entry['climberName'] as String? ?? 'Unknown';
        final rawBadges = entry['badges'] as List<dynamic>? ?? [];
        final badges = rawBadges.map((b) => model.Badge.fromJson(b)).toList();

        Widget rankWidget;
        if (rank == 1) {
          rankWidget =
              const Icon(Icons.emoji_events, color: Colors.amber, size: 32);
        } else if (rank == 2) {
          rankWidget =
              const Icon(Icons.emoji_events, color: Colors.grey, size: 32);
        } else if (rank == 3) {
          rankWidget = const Icon(Icons.emoji_events,
              color: Colors.deepOrange, size: 32);
        } else {
          rankWidget = CircleAvatar(
            radius: 16,
            child: Text('$rank'),
          );
        }

        return ListTile(
          leading: rankWidget,
          title: Text(climberName,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Score: $score | Sessions: $sessions'),
          trailing: badges.isEmpty
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: badges.map((b) {
                    IconData iconData = Icons.emoji_events;
                    if (b.icon == 'trophy') {
                      iconData = Icons.emoji_events;
                    } else if (b.icon == 'medal') {
                      iconData = Icons.workspace_premium;
                    } else if (b.icon == 'star') {
                      iconData = Icons.star;
                    }
                    return Tooltip(
                      message: b.name,
                      child: Icon(iconData, color: Colors.amber, size: 28),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}
