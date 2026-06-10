import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/group.dart';
import '../providers/group_provider.dart';
import '../services/auth_service.dart';
import 'create_group_page.dart';
import 'group_detail_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GroupProvider>();
      provider.loadMyGroups();
      provider.loadPendingInvites();
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 &&
        context.read<GroupProvider>().discoverResults.isEmpty) {
      context.read<GroupProvider>().discoverGroups();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context
            .read<GroupProvider>()
            .discoverGroups(search: value.trim().isEmpty ? null : value.trim());
      }
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<Group>(
      MaterialPageRoute(builder: (_) => const CreateGroupPage()),
    );
    if (created != null && mounted) {
      context.read<GroupProvider>().loadMyGroups();
    }
  }

  Future<void> _openDetail(Group group) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupDetailPage(groupId: group.id)),
    );
    if (mounted) context.read<GroupProvider>().loadMyGroups();
  }

  Future<void> _joinGroup(Group group) async {
    final joined = await context.read<GroupProvider>().joinGroup(group.id);
    if (!mounted) return;
    if (joined != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${group.name}!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not join group. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId = AuthService().currentUserId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Groups', icon: Icon(Icons.group)),
            Tab(text: 'Discover', icon: Icon(Icons.explore)),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _openCreate,
            icon: const Icon(Icons.group_add),
            label: const Text('New group'),
          );
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.surface,
              cs.surfaceContainerHighest.withValues(alpha: 0.85),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _MyGroupsTab(
              currentUserId: currentUserId,
              onOpenDetail: _openDetail,
            ),
            _DiscoverTab(
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
              onJoin: _joinGroup,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── My Groups tab ──────────────────────────────────────────────────────────

class _MyGroupsTab extends StatelessWidget {
  const _MyGroupsTab({
    required this.currentUserId,
    required this.onOpenDetail,
  });

  final String currentUserId;
  final void Function(Group) onOpenDetail;

  Future<void> _refresh(BuildContext context) {
    final p = context.read<GroupProvider>();
    return Future.wait([p.loadMyGroups(), p.loadPendingInvites()]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<GroupProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.groups.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null && provider.groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: cs.error, size: 44),
                const SizedBox(height: 12),
                Text(provider.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => provider.loadMyGroups(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final invites = provider.pendingInvites;
        final groups = provider.groups;

        if (invites.isEmpty && groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group_outlined, size: 56, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No groups yet',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Create a group or discover public groups to get started.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: CustomScrollView(
            slivers: [
              if (invites.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Pending invitations',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  sliver: SliverList.separated(
                    itemCount: invites.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _InvitationCard(invitation: invites[i]),
                  ),
                ),
              ],
              if (groups.isNotEmpty) ...[
                if (invites.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'My groups',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      16, invites.isEmpty ? 12 : 4, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _GroupCard(
                      group: groups[i],
                      currentUserId: currentUserId,
                      onTap: () => onOpenDetail(groups[i]),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Discover tab ───────────────────────────────────────────────────────────

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab({
    required this.searchController,
    required this.onSearchChanged,
    required this.onJoin,
  });

  final TextEditingController searchController;
  final void Function(String) onSearchChanged;
  final Future<void> Function(Group) onJoin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<GroupProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SearchBar(
                controller: searchController,
                hintText: 'Search public groups…',
                leading: const Icon(Icons.search),
                trailing: [
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    ),
                ],
                onChanged: onSearchChanged,
              ),
            ),
            Expanded(
              child: _buildResults(context, provider, cs),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResults(
    BuildContext context,
    GroupProvider provider,
    ColorScheme cs,
  ) {
    if (provider.isDiscovering) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.discoverResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              searchController.text.trim().isNotEmpty
                  ? 'No groups match your search.'
                  : 'No public groups to discover yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => provider.discoverGroups(
        search: searchController.text.trim().isEmpty
            ? null
            : searchController.text.trim(),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: provider.discoverResults.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final group = provider.discoverResults[i];
          return _DiscoverGroupCard(group: group, onJoin: () => onJoin(group));
        },
      ),
    );
  }
}

// ─── Widgets ────────────────────────────────────────────────────────────────

class _InvitationCard extends StatefulWidget {
  const _InvitationCard({required this.invitation});

  final GroupInvitation invitation;

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  bool _accepting = false;
  bool _declining = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final ok =
        await context.read<GroupProvider>().acceptInvite(widget.invitation.id);
    if (!mounted) return;
    setState(() => _accepting = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not accept invitation.')),
      );
    }
  }

  Future<void> _decline() async {
    setState(() => _declining = true);
    final ok =
        await context.read<GroupProvider>().declineInvite(widget.invitation.id);
    if (!mounted) return;
    setState(() => _declining = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not decline invitation.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final inv = widget.invitation;
    final busy = _accepting || _declining;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.secondaryContainer),
      ),
      color: cs.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.secondaryContainer,
                  child: Icon(Icons.group, size: 20, color: cs.onSecondaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.groupName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (inv.groupDescription != null &&
                          inv.groupDescription!.isNotEmpty)
                        Text(
                          inv.groupDescription!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Invited by ${inv.invitedByName ?? inv.invitedByUsername ?? 'someone'}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : _accept,
                    child: _accepting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : _decline,
                    child: _declining
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.currentUserId,
    required this.onTap,
  });

  final Group group;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final memberCount = group.members.length;
    final isAdmin =
        group.members.any((m) => m.userId == currentUserId && m.isAdmin);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.group, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (group.isPublic)
                          Tooltip(
                            message: 'Public group',
                            child: Icon(
                              Icons.public,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    if (group.description != null &&
                        group.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.people_outline,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 10),
                          Chip(
                            label: const Text('Admin'),
                            padding: EdgeInsets.zero,
                            labelPadding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: cs.primaryContainer,
                            labelStyle: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverGroupCard extends StatefulWidget {
  const _DiscoverGroupCard({required this.group, required this.onJoin});

  final Group group;
  final Future<void> Function() onJoin;

  @override
  State<_DiscoverGroupCard> createState() => _DiscoverGroupCardState();
}

class _DiscoverGroupCardState extends State<_DiscoverGroupCard> {
  bool _joining = false;

  Future<void> _handleJoin() async {
    setState(() => _joining = true);
    await widget.onJoin();
    if (mounted) setState(() => _joining = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final group = widget.group;
    final memberCount = group.memberCount ?? group.members.length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: cs.tertiaryContainer,
              child: Icon(Icons.group, color: cs.onTertiaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (group.description != null &&
                      group.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      group.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _joining
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton(
                    onPressed: _handleJoin,
                    child: const Text('Join'),
                  ),
          ],
        ),
      ),
    );
  }
}
