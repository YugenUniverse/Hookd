import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/climbing_session.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../dialogs/login_dialog.dart';
import '../services/auth_service.dart';
import 'edit_profile_page.dart';
import '../utils/image_helpers.dart';
import 'my_issues_page.dart';
import 'notifications_page.dart';
import 'wall_issues_page.dart';
import '../providers/notification_provider.dart';
import '../widgets/follow_list_sheet.dart';

class _UserPageData {
  const _UserPageData({
    required this.user,
    required this.sessions,
    required this.followerCount,
    required this.followingCount,
  });

  final User user;
  final List<ClimbingSession> sessions;
  final int followerCount;
  final int followingCount;
}

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  late Future<_UserPageData> _profileFuture;
  static const int _initialActivityCount = 3;

  int _visibleActivityCount = _initialActivityCount;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<_UserPageData> _loadProfile() async {
    final apiService = ApiService();
    final bearerToken = AuthService().jwt;
    // Ensure we're authenticated before attempting protected requests.
    if (!AuthService().isAuthenticated) {
      final loggedIn = await showLoginDialog(context);
      if (loggedIn != true || !AuthService().isAuthenticated) {
        throw StateError('Not authenticated');
      }
    }
    final results = await Future.wait([
      apiService.fetchCurrentUserProfile(bearerToken: bearerToken),
      apiService.fetchCurrentUserSessions(bearerToken: bearerToken),
    ]);

    final user = results[0] as User;
    AuthService().setCurrentUserProfile(
      avatar: user.profilePictureUrl ?? '',
      username: user.username,
    );

    final followResults = await Future.wait([
      apiService.getMyFollowers(),
      apiService.getFollowing(),
    ]);

    return _UserPageData(
      user: user,
      sessions: results[1] as List<ClimbingSession>,
      followerCount: (followResults[0] as List).length,
      followingCount: (followResults[1] as List).length,
    );
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = _loadProfile();
      _visibleActivityCount = _initialActivityCount;
    });
  }

  Future<void> _logout() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Do you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await AuthService().logout();
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Logged out')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerHighest.withOpacity(0.85),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<_UserPageData>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 44,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load profile',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _refreshProfile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final pageData = snapshot.data;
              if (pageData == null) {
                return const Center(child: Text('No profile data available.'));
              }

              final user = pageData.user;
              final sessions = [...pageData.sessions]
                ..sort((a, b) => b.date.compareTo(a.date));
              final visibleSessions = sessions
                  .take(_visibleActivityCount)
                  .toList();
              final hiddenCount = sessions.length - visibleSessions.length;

              final username = user.username.isNotEmpty
                  ? user.username
                  : 'User';
              final initial = username.isNotEmpty
                  ? username[0].toUpperCase()
                  : '?';
              final String memberSince = user.createdAt != null
                  ? MaterialLocalizations.of(
                      context,
                    ).formatShortDate(user.createdAt!)
                  : 'Unknown';
              final totalClimbs = sessions.length;
              final walletScore = user.wallet?.score ?? 0;
              final earnedBadges = user.wallet?.badges ?? [];

              return RefreshIndicator(
                onRefresh: () async => _refreshProfile(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  children: [
                    // Responsive container width for mobile
                    Builder(
                      builder: (ctx) {
                        final screenWidth = MediaQuery.of(ctx).size.width;
                        final dialogMaxWidth = screenWidth < 600
                            ? screenWidth * 0.96
                            : 560.0;
                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: dialogMaxWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    color: colorScheme.surfaceContainerHighest
                                        .withOpacity(0.85),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withOpacity(0.35),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 36,
                                            backgroundColor:
                                                colorScheme.primaryContainer,
                                            backgroundImage:
                                                user.profilePictureUrl !=
                                                        null &&
                                                    user
                                                        .profilePictureUrl!
                                                        .isNotEmpty
                                                ? NetworkImage(
                                                    user.profilePictureUrl!,
                                                  )
                                                : null,
                                            child:
                                                user.profilePictureUrl ==
                                                        null ||
                                                    user
                                                        .profilePictureUrl!
                                                        .isEmpty
                                                ? Text(
                                                    initial,
                                                    style: theme
                                                        .textTheme
                                                        .headlineMedium
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onPrimaryContainer,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  username,
                                                  style: theme
                                                      .textTheme
                                                      .headlineMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  user.email.isNotEmpty
                                                      ? user.email
                                                      : 'No email on file',
                                                  style: theme
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                                const SizedBox(height: 12),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    _StatusChip(
                                                      label: user.isAdmin
                                                          ? 'Admin'
                                                          : 'Member',
                                                      icon: user.isAdmin
                                                          ? Icons.shield
                                                          : Icons.person,
                                                    ),
                                                    _StatusChip(
                                                      label: user.originalMember
                                                          ? 'Original member'
                                                          : 'Climber',
                                                      icon: Icons.terrain,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      if (user.wallet != null) ...[
                                        _MedalCollectionWidget(
                                          user: user,
                                          earnedBadges: earnedBadges,
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      _InfoTile(
                                        icon: Icons.terrain_outlined,
                                        title: 'Total climbs',
                                        value: totalClimbs.toString(),
                                      ),
                                      const SizedBox(height: 12),
                                      _InfoTile(
                                        icon: Icons.calendar_month_outlined,
                                        title: 'Member since',
                                        value: memberSince,
                                      ),
                                      const SizedBox(height: 12),
                                      _InfoTile(
                                        icon: Icons
                                            .account_balance_wallet_outlined,
                                        title: 'Wallet Score',
                                        value: walletScore.toString(),
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _FollowCountButton(
                                              count: pageData.followerCount,
                                              label: 'Followers',
                                              onTap: () => showFollowListSheet(
                                                context,
                                                userId: user.id,
                                                type: FollowListType.followers,
                                                count: pageData.followerCount,
                                              ),
                                            ),
                                          ),
                                          Container(width: 1, height: 36,
                                              color: colorScheme.outlineVariant),
                                          Expanded(
                                            child: _FollowCountButton(
                                              count: pageData.followingCount,
                                              label: 'Following',
                                              onTap: () => showFollowListSheet(
                                                context,
                                                userId: user.id,
                                                type: FollowListType.following,
                                                count: pageData.followingCount,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Divider(),
                                      IconButton(
                                        tooltip: 'Edit profile',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () async {
                                          final updated = await Navigator.of(context).push<User>(
                                            MaterialPageRoute(
                                              builder: (_) => EditProfilePage(user: user),
                                            ),
                                          );
                                          if (updated != null) _refreshProfile();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _IssuesButton(userType: AuthService().userType),
                                const SizedBox(height: 20),
                                Text(
                                  'Activity',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (sessions.isEmpty)
                                  _EmptyActivityState(colorScheme: colorScheme)
                                else
                                  ...visibleSessions.map(
                                    (session) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _SessionActivityCard(
                                        session: session,
                                      ),
                                    ),
                                  ),
                                if (hiddenCount > 0) ...[
                                  const SizedBox(height: 4),
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _visibleActivityCount +=
                                              _initialActivityCount;
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
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SessionActivityCard extends StatelessWidget {
  const _SessionActivityCard({required this.session});

  final ClimbingSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final day = session.date.day.toString().padLeft(2, '0');
    final month = session.date.month.toString().padLeft(2, '0');
    final dateLabel = '$day/$month/${session.date.year}';
    final hasReview = session.reviewRating != null && session.reviewRating! > 0;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (session.isPrivate)
                _MiniBadge(label: 'Private'),
              Icon(Icons.terrain_outlined, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 8),
          if (session.wallName?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                session.wallName!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          Text(
            'Duration: ${session.time} min',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (hasReview) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(5, (i) {
                    final filled = i < session.reviewRating!;
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: filled
                          ? Colors.amber.shade400
                          : cs.outlineVariant,
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

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
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
        color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'No sessions yet. Your logged climbs will appear here.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _FollowCountButton extends StatelessWidget {
  const _FollowCountButton({
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
            Text(
              '$count',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
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
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IssuesButton extends StatelessWidget {
  const _IssuesButton({required this.userType});

  final String? userType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isClimber = userType == null || userType == 'Climber';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                isClimber ? const MyIssuesPage() : const WallIssuesPage(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isClimber ? Icons.report_outlined : Icons.report_problem_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isClimber ? 'My reports' : 'Wall issues',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
            // Refresh notifications when returning
            notificationProvider.loadNotifications();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Icon(Icons.notifications_outlined, size: 20, color: colorScheme.primary),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onError,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Notifications',
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (unreadCount > 0)
                        Text(
                          '$unreadCount unread',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _getIconForBadge(String iconStr) {
  final str = iconStr.toLowerCase();
  if (str.contains('first_ascent')) return Icons.star;
  if (str.contains('century_club')) return Icons.workspace_premium;
  if (str.contains('weekend_warrior')) return Icons.weekend;
  if (str.contains('super_climber')) return Icons.flash_on;
  if (str.contains('dedicated'))
    return Icons.link; // Closest default to carabiner
  if (str.contains('streak')) return Icons.local_fire_department;
  return Icons.emoji_events;
}

class _MedalCollectionWidget extends StatefulWidget {
  const _MedalCollectionWidget({
    required this.user,
    required this.earnedBadges,
  });

  final User user;
  final List<dynamic> earnedBadges;

  @override
  State<_MedalCollectionWidget> createState() => _MedalCollectionWidgetState();
}

class _MedalCollectionWidgetState extends State<_MedalCollectionWidget> {
  void _showAllBadgesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BadgeProgressModal(
        user: widget.user,
        earnedBadges: widget.earnedBadges,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.earnedBadges.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.military_tech,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Medal Collection',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showAllBadgesModal(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'See All',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final sortedEarnedBadges = List<dynamic>.from(
                widget.earnedBadges,
              );
              sortedEarnedBadges.sort(
                (a, b) =>
                    (a.badge.level as num).compareTo(b.badge.level as num),
              );

              final double maxWidth = constraints.maxWidth;
              const double badgeSize = 52.0; // container size + padding
              const double spacing = 12.0;
              final int maxBadgesThatFit =
                  ((maxWidth + spacing) / (badgeSize + spacing)).floor();

              final bool needsShowMore =
                  sortedEarnedBadges.length > maxBadgesThatFit;
              final int displayCount = needsShowMore
                  ? maxBadgesThatFit - 1
                  : sortedEarnedBadges.length;
              final int hiddenCount = sortedEarnedBadges.length - displayCount;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < displayCount; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: spacing),
                      child: _buildBadgeIcon(
                        context,
                        sortedEarnedBadges[i].badge,
                      ),
                    ),
                  if (needsShowMore)
                    InkWell(
                      onTap: () => _showAllBadgesModal(context),
                      borderRadius: BorderRadius.circular(26),
                      child: Container(
                        width: badgeSize,
                        height: badgeSize,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+$hiddenCount',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(BuildContext context, dynamic badge) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor;
    Color iconColor;
    Color shadowColor;
    Color borderColor;
    double blurRadius;
    double spreadRadius;

    switch (badge.level) {
      case 1:
        bgColor = isDark
            ? Colors.amber.withOpacity(0.15)
            : Colors.amber.shade50;
        iconColor = Colors.amber.shade400;
        borderColor = Colors.amber.shade400;
        shadowColor = Colors.amber.withOpacity(0.4);
        blurRadius = 12;
        spreadRadius = 2;
        break;
      case 2:
        bgColor = isDark
            ? Colors.blueGrey.withOpacity(0.2)
            : Colors.blueGrey.shade50;
        iconColor = Colors.blueGrey.shade300;
        borderColor = Colors.blueGrey.shade300;
        shadowColor = Colors.transparent;
        blurRadius = 0;
        spreadRadius = 0;
        break;
      case 3:
        bgColor = isDark
            ? Colors.deepOrange.withOpacity(0.15)
            : Colors.orange.shade50;
        iconColor = Colors.deepOrange.shade300;
        borderColor = Colors.deepOrange.shade300;
        shadowColor = Colors.transparent;
        blurRadius = 0;
        spreadRadius = 0;
        break;
      default:
        bgColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
        iconColor = isDark ? Colors.white70 : Colors.black54;
        borderColor = isDark ? Colors.white12 : Colors.transparent;
        shadowColor = Colors.transparent;
        blurRadius = 0;
        spreadRadius = 0;
    }

    return Tooltip(
      message: '${badge.name}\n${badge.description ?? ""}'.trim(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: borderColor != Colors.transparent
              ? Border.all(color: borderColor, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(_getIconForBadge(badge.icon), size: 28, color: iconColor),
      ),
    );
  }
}

class _BadgeProgressModal extends StatefulWidget {
  final User user;
  final List<dynamic> earnedBadges;

  const _BadgeProgressModal({required this.user, required this.earnedBadges});

  @override
  State<_BadgeProgressModal> createState() => _BadgeProgressModalState();
}

class _BadgeProgressModalState extends State<_BadgeProgressModal> {
  bool _isLoading = true;

  Map<String, List<dynamic>> _earnedFamilies = {};
  Map<String, List<dynamic>> _unearnedFamilies = {};
  Set<String> _expandedSections = {};

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    _fetchAllBadges();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getBadgeFamily(dynamic badge) {
    if (badge.type == 'custom' || badge.type == 'event') return 'Custom';
    String name = badge.name.toLowerCase();
    if (name.contains('streak')) return 'Streak';
    if (name.contains('dedicated') ||
        name.contains('hookd') ||
        name.contains('century'))
      return 'Dedicated';
    return 'Other';
  }

  Future<void> _fetchAllBadges() async {
    try {
      final systemBadges = await ApiService().getSystemBadges();

      Map<String, List<dynamic>> earned = {};
      Map<String, List<dynamic>> unearned = {};

      for (var eb in widget.earnedBadges) {
        if (eb.badge.type == 'custom' || eb.badge.type == 'event') {
          earned.putIfAbsent('Custom', () => []).add(eb);
        }
      }

      for (var sb in systemBadges) {
        String family = _getBadgeFamily(sb);
        final earnedInfo = widget.earnedBadges.cast<dynamic?>().firstWhere(
          (eb) => eb?.badge?.id == sb.id,
          orElse: () => null,
        );

        if (earnedInfo != null) {
          earned.putIfAbsent(family, () => []).add(earnedInfo);
        } else {
          unearned.putIfAbsent(family, () => []).add(sb);
        }
      }

      // Earned badges: sort by level ascending (1, 2, 3, 4) so highest prestige is first
      earned.forEach((key, list) {
        list.sort(
          (a, b) => (a.badge.level as num).compareTo(b.badge.level as num),
        );
      });

      // Unearned badges: sort by level descending (4, 3, 2, 1) so easiest is first (next milestone)
      unearned.forEach((key, list) {
        list.sort((a, b) => (b.level as num).compareTo(a.level as num));
      });

      if (mounted) {
        setState(() {
          _earnedFamilies = earned;
          _unearnedFamilies = unearned;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double _calculateProgress(dynamic badge) {
    final name = badge.name.toLowerCase();
    if (name.contains("hookd"))
      return (widget.user.sessionCount / 10).clamp(0.0, 1.0);
    if (name.contains("dedicated climber"))
      return (widget.user.sessionCount / 30).clamp(0.0, 1.0);
    if (name.contains("half century"))
      return (widget.user.sessionCount / 50).clamp(0.0, 1.0);
    if (name.contains("century club"))
      return (widget.user.sessionCount / 100).clamp(0.0, 1.0);
    if (name.contains("first ascent"))
      return (widget.user.sessionCount / 1).clamp(0.0, 1.0);

    if (name.contains("1-month streak"))
      return (widget.user.maxStreak / 4).clamp(0.0, 1.0);
    if (name.contains("3-month streak"))
      return (widget.user.maxStreak / 12).clamp(0.0, 1.0);
    if (name.contains("6-month streak"))
      return (widget.user.maxStreak / 26).clamp(0.0, 1.0);
    if (name.contains("1-year streak"))
      return (widget.user.maxStreak / 52).clamp(0.0, 1.0);

    return 0.0;
  }

  Widget _buildBadgeCard(
    BuildContext context,
    dynamic badge, {
    bool isEarned = false,
    dynamic earnedInfo,
    bool isChild = false,
    bool isExpandable = false,
    String? sectionKey,
    bool isTopCard = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final double progress = isEarned ? 1.0 : _calculateProgress(badge);

    Color bgColor;
    Color iconColor;
    switch (badge.level) {
      case 1:
        bgColor = Colors.amber.withOpacity(0.15);
        iconColor = Colors.amber.shade400;
        break;
      case 2:
        bgColor = Colors.blueGrey.withOpacity(0.2);
        iconColor = Colors.blueGrey.shade300;
        break;
      case 3:
        bgColor = Colors.deepOrange.withOpacity(0.15);
        iconColor = Colors.deepOrange.shade300;
        break;
      default:
        bgColor = isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200;
        iconColor = isDark ? Colors.white70 : Colors.black54;
    }

    final bool isExpanded =
        sectionKey != null && _expandedSections.contains(sectionKey);

    final Color cardColor = Color.alphaBlend(
      colorScheme.surfaceVariant.withOpacity(0.4),
      colorScheme.surface,
    );
    final Color childCardColor = Color.alphaBlend(
      colorScheme.surfaceVariant.withOpacity(0.15),
      colorScheme.surface,
    );

    final GlobalKey? key = isTopCard && sectionKey != null
        ? _sectionKeys.putIfAbsent(sectionKey, () => GlobalKey())
        : null;

    return GestureDetector(
      onTap: isExpandable && sectionKey != null
          ? () {
              final RenderBox? box =
                  key?.currentContext?.findRenderObject() as RenderBox?;
              final double? oldY = box?.localToGlobal(Offset.zero).dy;

              setState(() {
                if (isExpanded) {
                  _expandedSections.remove(sectionKey);
                } else {
                  _expandedSections.add(sectionKey);
                }
              });

              if (oldY != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final RenderBox? newBox =
                      key?.currentContext?.findRenderObject() as RenderBox?;
                  if (newBox != null) {
                    final double newY = newBox.localToGlobal(Offset.zero).dy;
                    final double diff = newY - oldY;
                    if (diff != 0) {
                      _scrollController.jumpTo(
                        (_scrollController.offset + diff).clamp(
                          0.0,
                          _scrollController.position.maxScrollExtent,
                        ),
                      );
                    }
                  }
                });
              }
            }
          : null,
      child: Container(
        key: key,
        margin: EdgeInsets.only(
          bottom: isChild ? 8 : (isExpandable && !isExpanded ? 0 : 16),
          left: isChild ? 32 : 0,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isChild ? childCardColor : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEarned
                ? (badge.level < 4 ? iconColor : colorScheme.outlineVariant)
                : colorScheme.outline.withOpacity(0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(isChild ? 8 : 12),
              decoration: BoxDecoration(
                color: isEarned
                    ? bgColor
                    : (isDark ? Colors.grey.shade900 : Colors.grey.shade300),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconForBadge(badge.icon),
                size: isChild ? 24 : 32,
                color: isEarned
                    ? iconColor
                    : (isDark ? Colors.white24 : Colors.black26),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: isEarned
                            ? Text(
                                badge.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : ImageFilterWidget(
                                sigmaX: 2.5,
                                sigmaY: 3.5,
                                child: Text(
                                  badge.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                      ),
                      if (isExpandable)
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: colorScheme.onSurfaceVariant,
                        )
                      else if (isEarned)
                        Icon(
                          Icons.check_circle,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.description ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isEarned) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: colorScheme.outlineVariant
                                  .withOpacity(0.3),
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ] else if (earnedInfo != null) ...[
                    Text(
                      'Earned on ${earnedInfo.formattedDate}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedSection(
    BuildContext context,
    List<dynamic> badges, {
    required bool isEarned,
    required String sectionKey,
  }) {
    bool isExpanded = _expandedSections.contains(sectionKey);
    bool isExpandable = badges.length > 1;

    if (isExpanded || !isExpandable) {
      // Render sequentially
      return Column(
        children: [
          if (isExpanded && !isEarned)
            for (int i = badges.length - 1; i >= 1; i--)
              _buildBadgeCard(
                context,
                badges[i],
                isEarned: false,
                isChild: true,
              ),

          _buildBadgeCard(
            context,
            isEarned ? badges.first.badge : badges.first,
            isEarned: isEarned,
            earnedInfo: isEarned ? badges.first : null,
            isExpandable: isExpandable,
            sectionKey: sectionKey,
            isTopCard: true,
          ),

          if (isExpanded && isEarned)
            for (int i = 1; i < badges.length; i++)
              _buildBadgeCard(
                context,
                badges[i].badge,
                isEarned: true,
                earnedInfo: badges[i],
                isChild: true,
              ),
        ],
      );
    }

    // Collapsed Squashed View
    final double stackOffset = isEarned ? 16.0 : -16.0;
    final Alignment scaleAlignment = isEarned
        ? Alignment.topCenter
        : Alignment.bottomCenter;
    final double extraSpace = badges.length > 2 ? 48.0 : 24.0;

    return Padding(
      padding: EdgeInsets.only(
        top: !isEarned ? extraSpace : 0,
        bottom: isEarned ? extraSpace : 16.0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: isEarned ? Alignment.topCenter : Alignment.bottomCenter,
        children: [
          if (badges.length > 2)
            Transform.translate(
              offset: Offset(0, stackOffset * 2),
              child: Transform.scale(
                scale: 0.9,
                alignment: scaleAlignment,
                child: IgnorePointer(
                  child: _buildBadgeCard(
                    context,
                    isEarned ? badges[2].badge : badges[2],
                    isEarned: isEarned,
                    earnedInfo: isEarned ? badges[2] : null,
                    isExpandable: true,
                    sectionKey: sectionKey,
                  ),
                ),
              ),
            ),
          if (badges.length > 1)
            Transform.translate(
              offset: Offset(0, stackOffset),
              child: Transform.scale(
                scale: 0.95,
                alignment: scaleAlignment,
                child: IgnorePointer(
                  child: _buildBadgeCard(
                    context,
                    isEarned ? badges[1].badge : badges[1],
                    isEarned: isEarned,
                    earnedInfo: isEarned ? badges[1] : null,
                    isExpandable: true,
                    sectionKey: sectionKey,
                  ),
                ),
              ),
            ),
          _buildBadgeCard(
            context,
            isEarned ? badges.first.badge : badges.first,
            isEarned: isEarned,
            earnedInfo: isEarned ? badges.first : null,
            isExpandable: true,
            sectionKey: sectionKey,
            isTopCard: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<Widget> listItems = [];

    final orderedFamilies = ['Custom', 'Streak', 'Dedicated', 'Other'];

    for (String family in orderedFamilies) {
      final unearnedBadges = _unearnedFamilies[family] ?? [];
      final earnedBadges = _earnedFamilies[family] ?? [];

      if (unearnedBadges.isEmpty && earnedBadges.isEmpty) continue;

      // Family Title for visual spacing
      listItems.add(
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Text(
            family == 'Other' ? 'Miscellaneous' : '$family Badges',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ),
      );

      if (unearnedBadges.isNotEmpty) {
        listItems.add(
          _buildStackedSection(
            context,
            unearnedBadges,
            isEarned: false,
            sectionKey: '${family}_unearned',
          ),
        );
      }

      if (earnedBadges.isNotEmpty) {
        listItems.add(
          _buildStackedSection(
            context,
            earnedBadges,
            isEarned: true,
            sectionKey: '${family}_earned',
          ),
        );
      }

      listItems.add(const SizedBox(height: 16)); // Spacing between families
    }

    if (listItems.isEmpty && !_isLoading) {
      listItems.add(const Center(child: Text('No badges to show.')));
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'All Badges',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    children: listItems,
                  ),
          ),
        ],
      ),
    );
  }
}

class ImageFilterWidget extends StatelessWidget {
  final Widget child;
  final double sigmaX;
  final double sigmaY;

  const ImageFilterWidget({
    super.key,
    required this.child,
    this.sigmaX = 3,
    this.sigmaY = 3,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ImageFiltered(
        imageFilter: dart_ui.ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: child,
      ),
    );
  }
}
