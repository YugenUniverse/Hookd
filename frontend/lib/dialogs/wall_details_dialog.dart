import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../dialogs/login_dialog.dart';
import '../models/leaderboard_entry.dart';
import '../models/review.dart';
import '../models/wall.dart';
import '../pages/log_session_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/leaderboard_list.dart';

class WallDetailsDialog extends StatefulWidget {
  final Wall wall;
  final VoidCallback? onChanged;

  const WallDetailsDialog({super.key, required this.wall, this.onChanged});

  @override
  State<WallDetailsDialog> createState() => _WallDetailsDialogState();
}

class _WallDetailsDialogState extends State<WallDetailsDialog> {
  late final Future<List<Review>> _reviewsFuture;
  late Future<_LeaderboardData> _leaderboardFuture;
  late Wall _wall;

  int _leaderboardOffset = 0;

  @override
  void initState() {
    super.initState();
    _wall = widget.wall;
    _reviewsFuture = ApiService().getWallReviews(widget.wall.id);
    _leaderboardFuture = _fetchLeaderboard();
    _fetchWallDetails();
  }

  Future<void> _fetchWallDetails() async {
    final fresh = await ApiService().getWallById(widget.wall.id);
    if (fresh == null || !mounted) {
      return;
    }

    setState(() {
      _wall = fresh;
    });
  }

  Future<_LeaderboardData> _fetchLeaderboard() async {
    final String baseUrl = kIsWeb
        ? 'http://localhost:3000'
        : 'http://10.0.2.2:3000';
    final token = AuthService().jwt;

    final response = await http.get(
      Uri.parse(
        '$baseUrl/walls/${widget.wall.id}/leaderboard?offset=$_leaderboardOffset',
      ),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load leaderboard');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rawList = decoded['leaderboard'];
    final leaderboard = rawList is List
        ? rawList
              .whereType<Map>()
              .map(
                (json) =>
                    LeaderboardEntry.fromJson(Map<String, dynamic>.from(json)),
              )
              .toList()
        : <LeaderboardEntry>[];

    return _LeaderboardData(
      seasonName: decoded['seasonName']?.toString() ?? 'Season',
      isHistorical: decoded['isHistorical'] == true,
      daysRemaining: _toInt(decoded['daysRemaining']),
      averageTime: _toInt(decoded['averageTime']),
      leaderboard: leaderboard,
    );
  }

  void _reloadLeaderboard() {
    setState(() {
      _leaderboardFuture = _fetchLeaderboard();
    });
  }

  void _changeSeason(int delta) {
    final nextOffset = _leaderboardOffset + delta;
    if (nextOffset > 0) {
      return;
    }

    setState(() {
      _leaderboardOffset = nextOffset;
    });
    _reloadLeaderboard();
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _handleLogSession(BuildContext context) async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    if (!AuthService().isAuthenticated) {
      final loggedIn = await showLoginDialog(rootContext);
      if (loggedIn != true || !AuthService().isAuthenticated) {
        return;
      }
    }

    if (!context.mounted || !rootContext.mounted) {
      return;
    }

    Navigator.of(context).pop();
    await showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => LogSessionPage(initialWall: _wall),
    );
  }

  bool get _isOwner {
    final userType = AuthService().userType;
    if (userType == 'FacilityOwner' && _wall.wallType == 'IndoorWall')
      return true;
    if (userType == 'PublicBody' && _wall.wallType == 'OutdoorWall')
      return true;
    return false;
  }

  Future<void> _showEditDialog() async {
    final wall = _wall;
    final result =
        await showDialog<
          ({String name, String description, String difficulty})
        >(
          context: context,
          builder: (_) => _EditWallDialog(wall: wall),
        );
    if (result == null || !mounted) return;

    final ok = await ApiService().updateWall(
      wall.id,
      name: result.name,
      description: result.description,
      difficulty: result.difficulty,
    );
    if (!mounted) return;

    if (ok) {
      setState(() {
        _wall = Wall(
          id: wall.id,
          name: result.name,
          description: result.description,
          difficulty: result.difficulty,
          wallType: wall.wallType,
          latitude: wall.latitude,
          longitude: wall.longitude,
          ownerName: wall.ownerName,
          sessions: wall.sessions,
          rating: wall.rating,
          totalSessions: wall.totalSessions,
          issues: wall.issues,
        );
      });
      widget.onChanged?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wall updated')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update wall')));
    }
  }

  Future<void> _confirmDelete() async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete wall?'),
        content: Text(
          'This will permanently delete "${_wall.name}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: errorColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await ApiService().deleteWall(_wall.id);
    if (!mounted) return;

    if (ok) {
      widget.onChanged?.call();
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Wall deleted')));
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to delete wall')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wall = _wall;
    final bool isIndoor = wall.wallType == 'IndoorWall';
    final IconData typeIcon = isIndoor ? Icons.domain : Icons.landscape;
    final Color typeColor = isIndoor ? Colors.blueGrey : Colors.green;
    final bool isAuthenticated = AuthService().isAuthenticated;
    final bool isOwner = _isOwner;

    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          width: double.infinity,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                      if (isOwner) ...[
                        IconButton(
                          tooltip: 'Edit wall',
                          onPressed: _showEditDialog,
                          icon: const Icon(Icons.edit_outlined),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        IconButton(
                          tooltip: 'Delete wall',
                          onPressed: _confirmDelete,
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ],
                      IconButton(
                        tooltip: isAuthenticated
                            ? 'Log session'
                            : 'Log session (login required)',
                        onPressed: () => _handleLogSession(context),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.edit_calendar_outlined),
                            if (!isAuthenticated)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Icon(
                                  Icons.lock_outline,
                                  size: 11,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      IconButton(
                        tooltip: 'Report an issue',
                        onPressed: () {
                          final TextEditingController issueController =
                              TextEditingController();
                          showDialog(
                            context: context,
                            builder: (context) => StatefulBuilder(
                              builder: (context, setState) => AlertDialog(
                                title: const Text('Report an issue'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Report an issue for ${wall.name}.'),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: issueController,
                                      maxLines: 5,
                                      decoration: const InputDecoration(
                                        hintText: 'Describe the issue...',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final issueBody = issueController.text
                                          .trim();
                                      if (issueBody.isNotEmpty) {
                                        final apiService = ApiService();
                                        final navigator = Navigator.of(context);
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        await apiService.createIssue(
                                          wallId: wall.id,
                                          body: issueBody,
                                        );
                                        navigator.pop();
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Issue submitted.'),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Submit'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.report_problem_outlined),
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Chip(
                    label: Text(
                      isIndoor ? 'Indoor Facility' : 'Outdoor Crag',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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
                    '${wall.totalSessions} sessions logged',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    context,
                    Icons.star,
                    'Mean Rating',
                    wall.rating > 0
                        ? wall.rating.toStringAsFixed(1)
                        : 'No rating yet',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wall.description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    tabs: const [
                      Tab(text: 'Reviews'),
                      Tab(text: 'Leaderboard'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildReviewsTab(context),
                        _buildLeaderboardTab(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsTab(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: _reviewsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load reviews right now.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        final reviews = snapshot.data ?? const <Review>[];
        if (reviews.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('No reviews yet for this wall.'),
            ),
          );
        }

        final hasPrivateReviews = reviews.any(
          (review) => review.sessionIsPrivate,
        );

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            if (hasPrivateReviews)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Private sessions are only visible to you, but they still count in the wall totals.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ...reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              child: Text(
                                review.reviewerName.isNotEmpty
                                    ? review.reviewerName[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    review.reviewerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_formatSessionStats(review).isNotEmpty)
                                    Text(
                                      _formatSessionStats(review),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (index) {
                                final filled = index < review.rating;
                                return Icon(
                                  filled ? Icons.star : Icons.star_border,
                                  size: 16,
                                  color: Colors.amber.shade700,
                                );
                              }),
                            ),
                          ],
                        ),
                        if (review.sessionIsPrivate) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Chip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              avatar: Icon(
                                Icons.lock_outline,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              label: const Text('Private'),
                            ),
                          ),
                        ],
                        if (review.body.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            review.body,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.4),
                          ),
                        ],
                        if (review.sessionIsPrivate) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Visible only to you.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeaderboardTab(BuildContext context) {
    return FutureBuilder<_LeaderboardData>(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading leaderboard.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        final data = snapshot.data!;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
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
                        data.seasonName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!data.isHistorical)
                        Text(
                          '${data.daysRemaining} days left',
                          style: TextStyle(
                            color: _getDaysLeftColor(data.daysRemaining),
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
                  onPressed: _leaderboardOffset < 0
                      ? () => _changeSeason(1)
                      : null,
                ),
              ],
            ),
            if (data.averageTime > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Community Average: ${data.averageTime} mins',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            LeaderboardList(
              climbers: data.leaderboard,
              emptyMessage: 'No ascents logged this season. Be the first!',
            ),
          ],
        );
      },
    );
  }

  // A helper widget to keep the code clean for rows with icons and text
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

  String _formatSessionStats(Review review) {
    final parts = <String>[];

    if (review.sessionTimeMinutes > 0) {
      parts.add(_formatDuration(review.sessionTimeMinutes));
    }

    final sessionDate = review.sessionDate;
    if (sessionDate != null) {
      parts.add(_formatDate(sessionDate));
    }

    return parts.join(' · ');
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) {
      return '';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '$minutes min';
    }

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}m';
  }

  String _formatDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  Color _getDaysLeftColor(int days) {
    if (days >= 45) return Colors.greenAccent.shade400;
    if (days >= 15) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

// ─── Edit wall dialog ─────────────────────────────────────────────────────────

class _EditWallDialog extends StatefulWidget {
  const _EditWallDialog({required this.wall});
  final Wall wall;

  @override
  State<_EditWallDialog> createState() => _EditWallDialogState();
}

class _EditWallDialogState extends State<_EditWallDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String _difficulty;

  static const _options = [
    'UNKNOWN',
    'BEGINNER',
    'INTERMEDIATE',
    'ADVANCED',
    'EXPERT',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.wall.name);
    _descCtrl = TextEditingController(text: widget.wall.description);
    _difficulty = _options.contains(widget.wall.difficulty.toUpperCase())
        ? widget.wall.difficulty.toUpperCase()
        : 'UNKNOWN';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    Navigator.of(context).pop((
      name: name,
      description: _descCtrl.text.trim(),
      difficulty: _difficulty,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit wall'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Difficulty'),
              items: _options
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _difficulty = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Apply')),
      ],
    );
  }
}

class _LeaderboardData {
  final String seasonName;
  final bool isHistorical;
  final int daysRemaining;
  final int averageTime;
  final List<LeaderboardEntry> leaderboard;

  const _LeaderboardData({
    required this.seasonName,
    required this.isHistorical,
    required this.daysRemaining,
    required this.averageTime,
    required this.leaderboard,
  });
}
