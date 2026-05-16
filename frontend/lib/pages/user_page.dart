import 'package:flutter/material.dart';

import '../models/climbing_session.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../dialogs/login_dialog.dart';
import '../services/auth_service.dart';
import 'my_issues_page.dart';
import 'wall_issues_page.dart';

class _UserPageData {
  const _UserPageData({required this.user, required this.sessions});

  final User user;
  final List<ClimbingSession> sessions;
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

    return _UserPageData(
      user: results[0] as User,
      sessions: results[1] as List<ClimbingSession>,
    );
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = _loadProfile();
      _visibleActivityCount = _initialActivityCount;
    });
  }

  Future<void> _logout() async {
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

    if (shouldLogout != true) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Logged out')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
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
              final visibleSessions = sessions.take(_visibleActivityCount).toList();
              final hiddenCount = sessions.length - visibleSessions.length;

              final username = user.username.isNotEmpty ? user.username : 'User';
              final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
              final String memberSince = user.createdAt != null
                  ? MaterialLocalizations.of(context).formatShortDate(
                      user.createdAt!,
                    )
                  : 'Unknown';
              final totalClimbs = sessions.length;

              return RefreshIndicator(
                onRefresh: () async => _refreshProfile(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  children: [
                    
                    // Responsive container width for mobile
                    Builder(builder: (ctx) {
                      final screenWidth = MediaQuery.of(ctx).size.width;
                      final dialogMaxWidth = screenWidth < 600 ? screenWidth * 0.96 : 560.0;
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: dialogMaxWidth),
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                color: colorScheme.surfaceContainerHighest.withOpacity(0.85),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withOpacity(0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 36,
                                        backgroundColor: colorScheme.primaryContainer,
                                        backgroundImage: user.profilePictureUrl != null &&
                                                user.profilePictureUrl!.isNotEmpty
                                            ? NetworkImage(user.profilePictureUrl!)
                                            : null,
                                        child: user.profilePictureUrl == null ||
                                                user.profilePictureUrl!.isEmpty
                                            ? Text(
                                                initial,
                                                style: theme.textTheme.headlineMedium
                                                    ?.copyWith(
                                                      color: colorScheme.onPrimaryContainer,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              username,
                                              style: theme.textTheme.headlineMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              user.email.isNotEmpty ? user.email : 'No email on file',
                                              style: theme.textTheme.bodyLarge?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _StatusChip(
                                                  label: user.isAdmin ? 'Admin' : 'Member',
                                                  icon: user.isAdmin ? Icons.shield : Icons.person,
                                                ),
                                                _StatusChip(
                                                  label: user.originalMember ? 'Original member' : 'Climber',
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
                                  padding: const EdgeInsets.only(bottom: 12),
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
    final colorScheme = theme.colorScheme;
    final dateLabel = _formatDate(session.date);
    final privacyLabel = session.isPrivate ? 'Private' : 'Public';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _MiniBadge(label: privacyLabel),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Wall: ${session.wallId.isNotEmpty ? session.wallId : 'Unknown'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Duration: ${session.time} min',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
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
            builder: (_) => isClimber ? const MyIssuesPage() : const WallIssuesPage(),
          ),
        );
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
            Icon(
              isClimber ? Icons.report_outlined : Icons.report_problem_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isClimber ? 'My reports' : 'Wall issues',
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
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
