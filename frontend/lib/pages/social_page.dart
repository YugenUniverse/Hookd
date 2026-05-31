import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/conversation.dart';
import '../models/group.dart';
import '../providers/group_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'chat_page.dart';
import 'climber_profile_page.dart';
import 'create_group_page.dart';
import 'group_detail_page.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Chats
  List<Conversation> _conversations = [];
  bool _chatsLoading = true;

  // Discover
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  int _discoverSegment = 0; // 0 = groups, 1 = people
  List<Map<String, dynamic>> _userResults = [];
  bool _usersLoading = false;
  bool _userSearchDone = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChats();
      final p = context.read<GroupProvider>();
      p.loadMyGroups();
      p.loadPendingInvites();
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 &&
        context.read<GroupProvider>().discoverResults.isEmpty) {
      context.read<GroupProvider>().discoverGroups();
    }
  }

  Future<void> _loadChats() async {
    setState(() => _chatsLoading = true);
    try {
      final convs = await ApiService().getConversations();
      if (mounted) setState(() => _conversations = convs);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _chatsLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (_discoverSegment == 0) {
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (mounted) {
          context
              .read<GroupProvider>()
              .discoverGroups(search: q.isEmpty ? null : q);
        }
      });
    } else {
      if (q.length < 2) {
        setState(() {
          _userResults = [];
          _userSearchDone = false;
        });
        return;
      }
      _debounce = Timer(const Duration(milliseconds: 350), () async {
        if (!mounted) return;
        setState(() => _usersLoading = true);
        try {
          final results = await ApiService().searchClimbers(q);
          if (mounted) {
            setState(() {
              _userResults = results;
              _userSearchDone = true;
            });
          }
        } catch (_) {
        } finally {
          if (mounted) setState(() => _usersLoading = false);
        }
      });
    }
  }

  Future<void> _openGroupDetail(Group group) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupDetailPage(groupId: group.id)),
    );
    if (mounted) {
      context.read<GroupProvider>().loadMyGroups();
      _loadChats();
    }
  }

  Future<void> _openGroupChat(Group group) async {
    try {
      final conv = await ApiService().getGroupConversation(group.id);
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ChatPage(conversation: conv)));
      if (mounted) _loadChats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
    }
  }

  Future<void> _openDmConversation(Conversation conv) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ChatPage(conversation: conv)));
    if (mounted) _loadChats();
  }

  Future<void> _joinGroup(Group group) async {
    final joined = await context.read<GroupProvider>().joinGroup(group.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(joined != null
          ? 'Joined ${group.name}!'
          : 'Could not join group. Please try again.'),
    ));
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<Group>(
      MaterialPageRoute(builder: (_) => const CreateGroupPage()),
    );
    if (created != null && mounted) {
      context.read<GroupProvider>().loadMyGroups();
      _loadChats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId = AuthService().currentUserId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chats', icon: Icon(Icons.chat_bubble_outline)),
            Tab(text: 'Discover', icon: Icon(Icons.explore_outlined)),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (_tabController.index == 0) {
            return FloatingActionButton(
              heroTag: 'social_new_dm',
              tooltip: 'New message',
              onPressed: _showNewDmSheet,
              child: const Icon(Icons.edit_outlined),
            );
          }
          if (_discoverSegment == 0) {
            return FloatingActionButton.extended(
              heroTag: 'social_new_group',
              onPressed: _openCreate,
              icon: const Icon(Icons.group_add),
              label: const Text('New group'),
            );
          }
          return const SizedBox.shrink();
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
            _ChatsTab(
              conversations: _conversations,
              loading: _chatsLoading,
              currentUserId: currentUserId,
              onOpenDm: _openDmConversation,
              onOpenGroupChat: _openGroupChat,
              onOpenGroupDetail: _openGroupDetail,
              onRefresh: _loadChats,
            ),
            _DiscoverTab(
              searchCtrl: _searchCtrl,
              segment: _discoverSegment,
              onSegmentChanged: (v) {
                setState(() {
                  _discoverSegment = v;
                  _searchCtrl.clear();
                  _userResults = [];
                  _userSearchDone = false;
                });
                if (v == 0) {
                  context.read<GroupProvider>().discoverGroups();
                }
              },
              onSearchChanged: _onSearchChanged,
              userResults: _userResults,
              usersLoading: _usersLoading,
              userSearchDone: _userSearchDone,
              onJoinGroup: _joinGroup,
              onSegmentUpdate: (v) => setState(() => _discoverSegment = v),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewDmSheet() {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool loading = false;
    Timer? debounce;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void onSearch(String q) {
            debounce?.cancel();
            if (q.trim().length < 2) {
              setLocal(() => results = []);
              return;
            }
            debounce = Timer(const Duration(milliseconds: 350), () async {
              setLocal(() => loading = true);
              try {
                final r = await ApiService().searchClimbers(q.trim());
                setLocal(() => results = r);
              } catch (_) {
              } finally {
                setLocal(() => loading = false);
              }
            });
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SearchBar(
                    controller: searchCtrl,
                    hintText: 'Search by username…',
                    leading: const Icon(Icons.search),
                    autoFocus: true,
                    onChanged: onSearch,
                  ),
                ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : results.isEmpty
                          ? Center(
                              child: Text(
                                searchCtrl.text.trim().length < 2
                                    ? 'Type at least 2 characters'
                                    : 'No users found',
                                style: TextStyle(
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollCtrl,
                              itemCount: results.length,
                              itemBuilder: (_, i) {
                                final u = results[i];
                                final uid = (u['id'] ?? u['_id'] ?? '').toString();
                                final uname = u['username']?.toString() ?? '';
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(uname.isNotEmpty
                                        ? uname[0].toUpperCase()
                                        : '?'),
                                  ),
                                  title: Text('@$uname'),
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    try {
                                      final conv = await ApiService()
                                          .getOrCreateDm(uid);
                                      if (!mounted) return;
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ChatPage(conversation: conv),
                                        ),
                                      );
                                      if (mounted) _loadChats();
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text('$e')));
                                    }
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      searchCtrl.dispose();
      debounce?.cancel();
    });
  }
}

// ─── Chats tab ───────────────────────────────────────────────────────────────

class _ChatsTab extends StatelessWidget {
  const _ChatsTab({
    required this.conversations,
    required this.loading,
    required this.currentUserId,
    required this.onOpenDm,
    required this.onOpenGroupChat,
    required this.onOpenGroupDetail,
    required this.onRefresh,
  });

  final List<Conversation> conversations;
  final bool loading;
  final String currentUserId;
  final Future<void> Function(Conversation) onOpenDm;
  final Future<void> Function(Group) onOpenGroupChat;
  final Future<void> Function(Group) onOpenGroupDetail;
  final Future<void> Function() onRefresh;

  Future<void> _refresh(BuildContext context) {
    final p = context.read<GroupProvider>();
    return Future.wait([
      onRefresh(),
      p.loadMyGroups(),
      p.loadPendingInvites(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<GroupProvider>(
      builder: (context, provider, _) {
        final invites = provider.pendingInvites;
        final groups = provider.groups;

        // Build a map groupId → Conversation for quick lookup
        final groupConvMap = <String, Conversation>{};
        final dmConvs = <Conversation>[];
        for (final c in conversations) {
          if (c.type == 'group' && c.groupId != null) {
            groupConvMap[c.groupId!] = c;
          } else if (c.type == 'dm') {
            dmConvs.add(c);
          }
        }

        final isEmpty = invites.isEmpty && groups.isEmpty && dmConvs.isEmpty;

        if (loading && isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 56, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('Nothing here yet',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Create a group or search for someone to message.',
                  style: TextStyle(color: cs.onSurfaceVariant),
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
              // Pending invitations
              if (invites.isNotEmpty) ...[
                _sectionHeader(context, 'Pending invitations', cs),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  sliver: SliverList.separated(
                    itemCount: invites.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) =>
                        _InvitationCard(invitation: invites[i]),
                  ),
                ),
              ],

              // Group chats
              if (groups.isNotEmpty) ...[
                _sectionHeader(context, 'Groups', cs),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  sliver: SliverList.separated(
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final g = groups[i];
                      final conv = groupConvMap[g.id];
                      return _GroupChatCard(
                        group: g,
                        conversation: conv,
                        currentUserId: currentUserId,
                        onOpenChat: () => onOpenGroupChat(g),
                        onOpenDetail: () => onOpenGroupDetail(g),
                      );
                    },
                  ),
                ),
              ],

              // Direct messages
              if (dmConvs.isNotEmpty) ...[
                _sectionHeader(context, 'Direct messages', cs),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: dmConvs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _DmCard(
                      conversation: dmConvs[i],
                      currentUserId: currentUserId,
                      onTap: () => onOpenDm(dmConvs[i]),
                    ),
                  ),
                ),
              ] else
                const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
            ],
          ),
        );
      },
    );
  }

  SliverPadding _sectionHeader(
      BuildContext context, String label, ColorScheme cs) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 4),
      sliver: SliverToBoxAdapter(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
        ),
      ),
    );
  }
}

// ─── Group chat card ─────────────────────────────────────────────────────────

class _GroupChatCard extends StatelessWidget {
  const _GroupChatCard({
    required this.group,
    required this.conversation,
    required this.currentUserId,
    required this.onOpenChat,
    required this.onOpenDetail,
  });

  final Group group;
  final Conversation? conversation;
  final String currentUserId;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final lastMsg = conversation?.lastMessage;
    final hasUnread = conversation?.hasUnread ?? false;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
      child: InkWell(
        onTap: onOpenChat,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.group, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastMsg != null)
                          Text(
                            _formatTime(conversation!.lastActivity),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMsg != null
                                ? '${lastMsg.senderUsername}: ${lastMsg.content}'
                                : 'No messages yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: hasUnread
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.info_outline,
                    size: 20, color: cs.onSurfaceVariant),
                tooltip: 'Group details',
                visualDensity: VisualDensity.compact,
                onPressed: onOpenDetail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DM card ─────────────────────────────────────────────────────────────────

class _DmCard extends StatelessWidget {
  const _DmCard({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final other = conversation.participants
        .where((p) => p.id != currentUserId)
        .firstOrNull;
    final name = other?.username ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final lastMsg = conversation.lastMessage;
    final hasUnread = conversation.hasUnread;

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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.secondaryContainer,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '@$name',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastMsg != null)
                          Text(
                            _formatTime(conversation.lastActivity),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMsg != null
                                ? lastMsg.content
                                : 'No messages yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: hasUnread
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Discover tab ────────────────────────────────────────────────────────────

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab({
    required this.searchCtrl,
    required this.segment,
    required this.onSegmentChanged,
    required this.onSearchChanged,
    required this.userResults,
    required this.usersLoading,
    required this.userSearchDone,
    required this.onJoinGroup,
    required this.onSegmentUpdate,
  });

  final TextEditingController searchCtrl;
  final int segment;
  final void Function(int) onSegmentChanged;
  final void Function(String) onSearchChanged;
  final List<Map<String, dynamic>> userResults;
  final bool usersLoading;
  final bool userSearchDone;
  final Future<void> Function(Group) onJoinGroup;
  final void Function(int) onSegmentUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Groups'),
                icon: Icon(Icons.group_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('People'),
                icon: Icon(Icons.person_search_outlined),
              ),
            ],
            selected: {segment},
            onSelectionChanged: (s) => onSegmentChanged(s.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SearchBar(
            controller: searchCtrl,
            hintText: segment == 0
                ? 'Search public groups…'
                : 'Search by username…',
            leading: const Icon(Icons.search),
            trailing: [
              if (searchCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchCtrl.clear();
                    onSearchChanged('');
                  },
                ),
            ],
            onChanged: onSearchChanged,
          ),
        ),
        Expanded(
          child: segment == 0
              ? _GroupsResults(
                  searchCtrl: searchCtrl,
                  onJoin: onJoinGroup,
                )
              : _PeopleResults(
                  results: userResults,
                  loading: usersLoading,
                  searchDone: userSearchDone,
                  query: searchCtrl.text,
                ),
        ),
      ],
    );
  }
}

class _GroupsResults extends StatelessWidget {
  const _GroupsResults({
    required this.searchCtrl,
    required this.onJoin,
  });

  final TextEditingController searchCtrl;
  final Future<void> Function(Group) onJoin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<GroupProvider>(
      builder: (context, provider, _) {
        if (provider.isDiscovering) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.discoverResults.isEmpty) {
          return Center(
            child: Text(
              searchCtrl.text.trim().isNotEmpty
                  ? 'No groups match your search.'
                  : 'No public groups to discover yet.',
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => provider.discoverGroups(
            search: searchCtrl.text.trim().isEmpty
                ? null
                : searchCtrl.text.trim(),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: provider.discoverResults.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final group = provider.discoverResults[i];
              return _DiscoverGroupCard(
                  group: group, onJoin: () => onJoin(group));
            },
          ),
        );
      },
    );
  }
}

class _PeopleResults extends StatelessWidget {
  const _PeopleResults({
    required this.results,
    required this.loading,
    required this.searchDone,
    required this.query,
  });

  final List<Map<String, dynamic>> results;
  final bool loading;
  final bool searchDone;
  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (loading) return const Center(child: CircularProgressIndicator());
    if (!searchDone || query.trim().length < 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_outlined,
                size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Search for climbers by username',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Text('No users found for "$query"',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final u = results[i];
        final uid = (u['id'] ?? u['_id'] ?? '').toString();
        final uname = u['username']?.toString() ?? '';
        final name = u['name']?.toString();
        final surname = u['surname']?.toString();
        final fullName = [name, surname]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');

        return _UserCard(
          userId: uid,
          username: uname,
          fullName: fullName.isNotEmpty ? fullName : null,
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.userId,
    required this.username,
    this.fullName,
  });

  final String userId;
  final String username;
  final String? fullName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ClimberProfilePage(
            userId: userId,
            initialUsername: username,
          ),
        )),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.secondaryContainer,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$username',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (fullName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        fullName!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
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

// ─── Shared sub-widgets (reused from groups_page) ────────────────────────────

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
          const SnackBar(content: Text('Could not accept invitation.')));
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
          const SnackBar(content: Text('Could not decline invitation.')));
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
                  child: Icon(Icons.group, size: 20,
                      color: cs.onSecondaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv.groupName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (inv.groupDescription?.isNotEmpty == true)
                        Text(inv.groupDescription!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Invited by ${inv.invitedByName ?? inv.invitedByUsername ?? 'someone'}',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : _accept,
                    child: _accepting
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : _decline,
                    child: _declining
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (group.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(group.description!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _joining
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : FilledButton(
                    onPressed: _handleJoin, child: const Text('Join')),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays == 0) return DateFormat.Hm().format(dt);
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return DateFormat.EEEE().format(dt);
  return DateFormat.yMd().format(dt);
}
