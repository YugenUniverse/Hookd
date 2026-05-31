import 'package:flutter/material.dart';

import '../models/climbing_session.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/follow_list_sheet.dart';
import 'chat_page.dart';
import 'edit_profile_page.dart';

class ClimberProfilePage extends StatefulWidget {
  final String userId;
  final String? initialUsername;

  const ClimberProfilePage({
    super.key,
    required this.userId,
    this.initialUsername,
  });

  @override
  State<ClimberProfilePage> createState() => _ClimberProfilePageState();
}

class _ClimberProfilePageState extends State<ClimberProfilePage> {
  User? _user;
  List<ClimbingSession> _sessions = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;
  String? _error;
  int _followerCount = 0;
  int _followingCount = 0;
  static const int _initialActivityCount = 3;
  int _visibleActivityCount = _initialActivityCount;

  bool get _isSelf => AuthService().currentUserId == widget.userId;
  bool get _viewerIsClimber => AuthService().userType == 'Climber';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _visibleActivityCount = _initialActivityCount;
    });
    try {
      final isAuth = AuthService().isAuthenticated;
      final results = await Future.wait<Object?>([
        ApiService().fetchUserProfile(widget.userId),
        isAuth
            ? ApiService().checkFollowing(widget.userId)
            : Future.value(false),
        ApiService().getFollowers(widget.userId),
        ApiService().getFollowingUsers(widget.userId),
        isAuth
            ? ApiService().getPublicSessions(widget.userId)
            : Future.value(<ClimbingSession>[]),
      ]);
      if (mounted) {
        setState(() {
          _user = results[0] as User;
          _isFollowing = results[1] as bool;
          _followerCount = (results[2] as List).length;
          _followingCount = (results[3] as List).length;
          _sessions = (results[4] as List)
              .map((e) => e as ClimbingSession)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) {
        await ApiService().unfollowUser(widget.userId);
        if (mounted) setState(() { _isFollowing = false; _followerCount--; });
      } else {
        await ApiService().followUser(widget.userId);
        if (mounted) setState(() { _isFollowing = true; _followerCount++; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _openDm() async {
    try {
      final Conversation conv = await ApiService().getOrCreateDm(widget.userId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatPage(conversation: conv)),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('403')
          ? "This user doesn't accept messages from you."
          : 'Could not open chat: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<User>(
      MaterialPageRoute(builder: (_) => EditProfilePage(user: _user!)),
    );
    if (updated != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = _user?.username ?? widget.initialUsername ?? 'Profile';

    return Scaffold(
      appBar: AppBar(title: Text('@$title'), centerTitle: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(error: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: () async => _load(),
                      child: _buildBody(context),
                    ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = _user!;

    final initial = user.username.isNotEmpty ? user.username[0].toUpperCase() : '?';
    final fullName = [user.name, user.surname]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    final badges = user.wallet?.badges ?? [];
    final visibleSessions = _sessions.take(_visibleActivityCount).toList();
    final hiddenCount = _sessions.length - visibleSessions.length;
    final String memberSince = user.createdAt != null
        ? MaterialLocalizations.of(context).formatShortDate(user.createdAt!)
        : 'Unknown';
    final hasStats = user.userType == 'Climber' &&
        (user.sessionCount > 0 ||
            user.maxStreak > 0 ||
            (user.wallet?.score ?? 0) > 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Builder(builder: (ctx) {
          final screenWidth = MediaQuery.of(ctx).size.width;
          final maxWidth = screenWidth < 600 ? screenWidth * 0.96 : 560.0;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header card ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.85),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar + name
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundColor: colorScheme.primaryContainer,
                              backgroundImage:
                                  (user.profilePictureUrl?.isNotEmpty == true)
                                      ? NetworkImage(user.profilePictureUrl!)
                                      : null,
                              child:
                                  (user.profilePictureUrl?.isNotEmpty == true)
                                      ? null
                                      : Text(
                                          initial,
                                          style: theme
                                              .textTheme.headlineMedium
                                              ?.copyWith(
                                            color:
                                                colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@${user.username}',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (fullName.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      fullName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        // ── Followers / Following ─────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _CountButton(
                                count: _followerCount,
                                label: 'Followers',
                                onTap: () => showFollowListSheet(
                                  context,
                                  userId: widget.userId,
                                  type: FollowListType.followers,
                                  count: _followerCount,
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: colorScheme.outlineVariant,
                            ),
                            Expanded(
                              child: _CountButton(
                                count: _followingCount,
                                label: 'Following',
                                onTap: () => showFollowListSheet(
                                  context,
                                  userId: widget.userId,
                                  type: FollowListType.following,
                                  count: _followingCount,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        // ── Action buttons ───────────────────────────────
                        if (_isSelf)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openEdit,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit Profile'),
                            ),
                          )
                        else if (_viewerIsClimber)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      _followLoading ? null : _toggleFollow,
                                  icon: _followLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : Icon(
                                          _isFollowing
                                              ? Icons.person_remove_outlined
                                              : Icons.person_add_outlined,
                                        ),
                                  label: Text(
                                      _isFollowing ? 'Unfollow' : 'Follow'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _openDm,
                                  icon: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 18),
                                  label: const Text('Message'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // ── Bio ──────────────────────────────────────────────────
                  if (user.bio?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote,
                              size: 20, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              user.bio!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Member since ─────────────────────────────────────────
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'Member since',
                    value: memberSince,
                  ),

                  // ── Stats row ────────────────────────────────────────────
                  if (hasStats) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.85),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Stat(
                              label: 'Sessions',
                              value: '${user.sessionCount}'),
                          Container(
                              width: 1,
                              height: 36,
                              color: colorScheme.outlineVariant),
                          _Stat(
                              label: 'Best streak',
                              value: '${user.maxStreak}'),
                          Container(
                              width: 1,
                              height: 36,
                              color: colorScheme.outlineVariant),
                          _Stat(
                              label: 'Score',
                              value: '${user.wallet?.score ?? 0}'),
                        ],
                      ),
                    ),
                  ],

                  // ── Badges ──────────────────────────────────────────────
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _EarnedBadgesCard(badges: badges),
                  ],

                  // ── Activity ─────────────────────────────────────────────
                  const SizedBox(height: 24),
                  Text(
                    'Activity',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (_sessions.isEmpty)
                    _EmptyActivityState(colorScheme: colorScheme)
                  else
                    ...visibleSessions.map(
                      (session) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SessionCard(session: session),
                      ),
                    ),
                  if (hiddenCount > 0) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _visibleActivityCount += _initialActivityCount;
                          });
                        },
                        icon: const Icon(Icons.expand_more),
                        label: Text('Show $hiddenCount more'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text('$count',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(value,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _EarnedBadgesCard extends StatelessWidget {
  const _EarnedBadgesCard({required this.badges});

  final List<dynamic> badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sorted = List<dynamic>.from(badges)
      ..sort((a, b) => (a.badge.level as num).compareTo(b.badge.level as num));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Badges',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: sorted
                .map((eb) => _buildBadgeIcon(context, eb.badge))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(BuildContext context, dynamic badge) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor;
    Color iconColor;
    Color borderColor;

    switch (badge.level) {
      case 1:
        bgColor = isDark
            ? Colors.amber.withValues(alpha: 0.15)
            : Colors.amber.shade50;
        iconColor = Colors.amber.shade400;
        borderColor = Colors.amber.shade400;
      case 2:
        bgColor = isDark
            ? Colors.blueGrey.withValues(alpha: 0.2)
            : Colors.blueGrey.shade50;
        iconColor = Colors.blueGrey.shade300;
        borderColor = Colors.blueGrey.shade300;
      case 3:
        bgColor = isDark
            ? Colors.deepOrange.withValues(alpha: 0.15)
            : Colors.orange.shade50;
        iconColor = Colors.deepOrange.shade300;
        borderColor = Colors.deepOrange.shade300;
      default:
        bgColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
        iconColor = isDark ? Colors.white70 : Colors.black54;
        borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    }

    return Tooltip(
      message: '${badge.name}\n${badge.description ?? ""}'.trim(),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Icon(
          _iconForBadge(badge.icon?.toString() ?? ''),
          size: 24,
          color: iconColor,
        ),
      ),
    );
  }
}

IconData _iconForBadge(String iconStr) {
  final str = iconStr.toLowerCase();
  if (str.contains('first_ascent')) return Icons.star;
  if (str.contains('century_club')) return Icons.workspace_premium;
  if (str.contains('weekend_warrior')) return Icons.weekend;
  if (str.contains('super_climber')) return Icons.flash_on;
  if (str.contains('dedicated')) return Icons.link;
  if (str.contains('streak')) return Icons.local_fire_department;
  return Icons.emoji_events;
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final ClimbingSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final day = session.date.day.toString().padLeft(2, '0');
    final month = session.date.month.toString().padLeft(2, '0');
    final dateLabel = '$day/$month/${session.date.year}';
    final hasReview =
        session.reviewRating != null && session.reviewRating! > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date row
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.terrain_outlined,
                  size: 18, color: cs.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 8),
          // Wall name
          if (session.wallName?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                session.wallName!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          // Duration
          Text(
            'Duration: ${session.time} min',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          // Review
          if (hasReview) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Star rating
                Row(
                  children: List.generate(5, (i) {
                    final filled = i < session.reviewRating!;
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: filled ? Colors.amber.shade400 : cs.outlineVariant,
                    );
                  }),
                ),
                if (session.reviewBody?.isNotEmpty == true) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.reviewBody!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyActivityState extends StatelessWidget {
  const _EmptyActivityState({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'No public activity yet.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: cs.error),
            const SizedBox(height: 12),
            Text('Unable to load profile',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
