import 'package:flutter/material.dart';

import '../models/badge.dart' show EarnedBadge;
import '../models/user.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/follow_list_sheet.dart';
import 'chat_page.dart';

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
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;
  String? _error;
  int _followerCount = 0;
  int _followingCount = 0;

  bool get _isSelf => AuthService().currentUserId == widget.userId;
  bool get _viewerIsClimber => AuthService().userType == 'Climber';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService().fetchUserProfile(widget.userId),
        ApiService().checkFollowing(widget.userId),
        ApiService().getFollowers(widget.userId),
        ApiService().getFollowingUsers(widget.userId),
      ]);
      if (mounted) {
        setState(() {
          _user = results[0] as User;
          _isFollowing = results[1] as bool;
          _followerCount = (results[2] as List).length;
          _followingCount = (results[3] as List).length;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
          ? 'This user doesn\'t accept messages from you.'
          : 'Could not open chat: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _user?.username ?? widget.initialUsername ?? 'Profile';
    return Scaffold(
      appBar: AppBar(title: Text('@$title')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _ProfileBody(
                  user: _user!,
                  isSelf: _isSelf,
                  viewerIsClimber: _viewerIsClimber,
                  isFollowing: _isFollowing,
                  followLoading: _followLoading,
                  followerCount: _followerCount,
                  followingCount: _followingCount,
                  onToggleFollow: _toggleFollow,
                  onDm: _openDm,
                  onShowFollowers: () => showFollowListSheet(
                    context,
                    userId: widget.userId,
                    type: FollowListType.followers,
                    count: _followerCount,
                  ),
                  onShowFollowing: () => showFollowListSheet(
                    context,
                    userId: widget.userId,
                    type: FollowListType.following,
                    count: _followingCount,
                  ),
                ),
    );
  }
}

// ─── Profile body ─────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.user,
    required this.isSelf,
    required this.viewerIsClimber,
    required this.isFollowing,
    required this.followLoading,
    required this.followerCount,
    required this.followingCount,
    required this.onToggleFollow,
    required this.onDm,
    required this.onShowFollowers,
    required this.onShowFollowing,
  });

  final User user;
  final bool isSelf;
  final bool viewerIsClimber;
  final bool isFollowing;
  final bool followLoading;
  final int followerCount;
  final int followingCount;
  final VoidCallback onToggleFollow;
  final VoidCallback onDm;
  final VoidCallback onShowFollowers;
  final VoidCallback onShowFollowing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final initial = user.username.isNotEmpty ? user.username[0].toUpperCase() : '?';
    final fullName = [user.name, user.surname]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    final badges = user.wallet?.badges ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // ── Header card ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              // Avatar + name row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: (user.profilePictureUrl?.isNotEmpty == true)
                        ? NetworkImage(user.profilePictureUrl!)
                        : null,
                    child: (user.profilePictureUrl?.isNotEmpty == true)
                        ? null
                        : Text(initial,
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: cs.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${user.username}',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (fullName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(fullName,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                        if (user.bio?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(user.bio!,
                              style: theme.textTheme.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // ── Followers / Following row ─────────────────────────────
              const SizedBox(height: 16),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: _CountButton(
                      count: followerCount,
                      label: 'Followers',
                      onTap: onShowFollowers,
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 36,
                      color: cs.outlineVariant),
                  Expanded(
                    child: _CountButton(
                      count: followingCount,
                      label: 'Following',
                      onTap: onShowFollowing,
                    ),
                  ),
                ],
              ),
              const Divider(),

              // ── Action buttons ───────────────────────────────────────
              if (!isSelf && viewerIsClimber) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: followLoading ? null : onToggleFollow,
                        icon: followLoading
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(isFollowing
                                ? Icons.person_remove_outlined
                                : Icons.person_add_outlined),
                        label: Text(isFollowing ? 'Unfollow' : 'Follow'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onDm,
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Message'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── Stats row ────────────────────────────────────────────────────
        if (user.userType == 'Climber' &&
            (user.sessionCount > 0 || user.maxStreak > 0 ||
                (user.wallet?.score ?? 0) > 0)) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(label: 'Sessions', value: '${user.sessionCount}'),
                _divider(cs),
                _Stat(label: 'Best streak', value: '${user.maxStreak}'),
                _divider(cs),
                _Stat(label: 'Score', value: '${user.wallet?.score ?? 0}'),
              ],
            ),
          ),
        ],

        // ── Badges ──────────────────────────────────────────────────────
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Badges',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges.map((b) => _BadgeChip(earned: b)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _divider(ColorScheme cs) =>
      Container(width: 1, height: 36, color: cs.outlineVariant);
}

// ─── Small widgets ────────────────────────────────────────────────────────────

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
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.earned});

  final EarnedBadge earned;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = earned.badge.name.isNotEmpty ? earned.badge.name : 'Badge';
    return Chip(
      avatar: const Icon(Icons.emoji_events, size: 16),
      label: Text(
        name,
        style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer),
      ),
      backgroundColor: cs.secondaryContainer,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error, style: TextStyle(color: cs.error)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
