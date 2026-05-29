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

class _GroupsPageState extends State<GroupsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GroupProvider>();
      provider.loadMyGroups();
      provider.loadPendingInvites();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId = AuthService().currentUserId ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('My Groups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.group_add),
        label: const Text('New group'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.surface, cs.surfaceContainerHighest.withValues(alpha: 0.85)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Consumer<GroupProvider>(
          builder: (context, provider, _) {
            Widget content;
            if (provider.isLoading) {
              content = const Center(child: CircularProgressIndicator());
            } else if (provider.error != null) {
              content = Center(
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
            } else if (provider.groups.isEmpty) {
              content = Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_outlined, size: 56, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'No groups yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a group to start climbing with friends.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            } else {
              content = RefreshIndicator(
                onRefresh: provider.loadMyGroups,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: provider.groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final group = provider.groups[i];
                    return _GroupCard(
                      group: group,
                      currentUserId: currentUserId,
                      onTap: () => _openDetail(group),
                    );
                  },
                ),
              );
            }

            final pendingCount = provider.pendingInvites.length;
            if (pendingCount == 0) return content;

            return Column(
              children: [
                _PendingInvitesBanner(count: pendingCount),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PendingInvitesBanner extends StatelessWidget {
  const _PendingInvitesBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        elevation: 0,
        color: cs.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.mail_outline, color: cs.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You have $count pending group ${count == 1 ? 'invitation' : 'invitations'}. Check your notifications to respond.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSecondaryContainer,
                      ),
                ),
              ),
            ],
          ),
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
    final isAdmin = group.members
        .any((m) => m.userId == currentUserId && m.isAdmin);

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
                    Text(
                      group.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (group.description != null && group.description!.isNotEmpty) ...[
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
                        Icon(Icons.people_outline, size: 14, color: cs.onSurfaceVariant),
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
                            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
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
