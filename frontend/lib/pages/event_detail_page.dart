import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/badge.dart' as model;
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/badge_icon.dart';

class EventDetailPage extends StatefulWidget {
  final Event event;

  const EventDetailPage({Key? key, required this.event}) : super(key: key);

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _leaderboard = [];
  List<model.Badge> _badges = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final leaderboardFuture = ApiService().getEventLeaderboard(widget.event.id);
      final badgesFuture = ApiService().getBadgesForEvent(widget.event.id);
      
      final results = await Future.wait([leaderboardFuture, badgesFuture]);
      
      final leaderboard = results[0] as List<Map<String, dynamic>>;
      final badges = results[1] as List<model.Badge>;

      // Sort badges from lowest value to highest value (Bronze -> Gold)
      badges.sort((a, b) {
        final valA = a.winningCondition?.value ?? 0;
        final valB = b.winningCondition?.value ?? 0;
        return valA.compareTo(valB);
      });

      setState(() {
        _leaderboard = leaderboard;
        _badges = badges;
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
        title: Text(widget.event.title),
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
            Text('Error loading event data',
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
                _fetchData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEventInfo(context),
        if (_badges.isNotEmpty) _buildProgressBar(context),
        const Divider(height: 1),
        Expanded(
          child: _leaderboard.isEmpty
              ? const Center(child: Text('No climbers have participated yet.'))
              : ListView.separated(
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
                      rankWidget = const Icon(Icons.emoji_events, color: Colors.amber, size: 32);
                    } else if (rank == 2) {
                      rankWidget = const Icon(Icons.emoji_events, color: Colors.grey, size: 32);
                    } else if (rank == 3) {
                      rankWidget = const Icon(Icons.emoji_events, color: Colors.deepOrange, size: 32);
                    } else {
                      rankWidget = CircleAvatar(
                        radius: 16,
                        child: Text('$rank'),
                      );
                    }

                    return ListTile(
                      leading: rankWidget,
                      title: Text(climberName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Score: $score | Sessions: $sessions'),
                      trailing: badges.isEmpty
                          ? null
                          : Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: badges.map((b) {
                                return BadgeIcon(
                                  name: b.name,
                                  description: b.description,
                                  level: b.level,
                                  iconStr: b.icon,
                                );
                              }).toList(),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventInfo(BuildContext context) {
    final e = widget.event;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateStr = e.endDate != null
        ? '${DateFormat('d MMM yyyy').format(e.startDate)} – ${DateFormat('d MMM yyyy').format(e.endDate!)}'
        : DateFormat('d MMM yyyy').format(e.startDate);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: e.isGlobal ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: e.isGlobal ? Border.all(color: Colors.amber.shade700, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(e.isGlobal ? Icons.public : Icons.event, 
                   color: e.isGlobal ? Colors.amber.shade900 : cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (e.status.toLowerCase() != 'active')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Closed', style: TextStyle(color: cs.onErrorContainer, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            e.isGlobal ? 'Global Challenge • $dateStr' : dateStr,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (e.description != null && e.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              e.description!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    final currentUserId = AuthService().currentUserId;
    int currentScore = 0;
    
    if (currentUserId != null) {
      try {
        final userEntry = _leaderboard.firstWhere((entry) => entry['climberId'] == currentUserId);
        currentScore = userEntry['score'] as int? ?? 0;
      } catch (e) {
        // User not found in leaderboard yet
      }
    }

    // Determine max required score for the highest badge
    final maxRequired = _badges.last.winningCondition?.value ?? 1;
    final progress = (currentScore / maxRequired).clamp(0.0, 1.0);

    // Find next tier
    model.Badge? nextBadge;
    for (var b in _badges) {
      final req = b.winningCondition?.value ?? 0;
      if (currentScore < req) {
        nextBadge = b;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Progress: $currentScore pts',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (nextBadge != null)
                Text(
                  '${(nextBadge.winningCondition?.value ?? 0) - currentScore} pts to ${nextBadge.name}',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                )
              else
                Text(
                  'Challenge Completed! 🎉',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Background bar
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              // Fill bar
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    height: 12,
                    width: constraints.maxWidth * progress,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                },
              ),
              // Markers for badges
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: _badges.map((b) {
                        final req = b.winningCondition?.value ?? 0;
                        final ratio = (req / maxRequired).clamp(0.0, 1.0);
                        final hasEarned = currentScore >= req;
                        
                        return Positioned(
                          left: (width * ratio) - 26, // center the marker (badge icon is ~52px wide)
                          top: -20, // adjust top based on BadgeIcon size
                          child: BadgeIcon(
                            name: b.name,
                            description: null,
                            level: hasEarned ? b.level : 4, // 4 = generic style
                            iconStr: b.icon,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
