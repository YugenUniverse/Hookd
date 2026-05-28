import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/poi.dart';
import '../models/wall.dart';
import '../pages/events_list_page.dart' show EventFormPage;
import '../pages/manage_event_badges_page.dart';
import '../pages/event_leaderboard_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../dialogs/wall_details_dialog.dart';

class FacilityDetailsDialog extends StatefulWidget {
  final FacilityPoi facility;
  final VoidCallback? onChanged;

  const FacilityDetailsDialog({
    super.key,
    required this.facility,
    this.onChanged,
  });

  @override
  State<FacilityDetailsDialog> createState() => _FacilityDetailsDialogState();
}

class _FacilityDetailsDialogState extends State<FacilityDetailsDialog>
    with SingleTickerProviderStateMixin {
  late List<IndoorWallSummary> _walls;
  List<Event> _events = [];
  bool _eventsLoading = false;
  bool? _isSubscribed;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _walls = List.of(widget.facility.walls);
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();
    if (_canFollow) _loadSubscriptionStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isOwner =>
      AuthService().userType == 'FacilityOwner' &&
      widget.facility.ownerAccountId != null &&
      AuthService().currentUserId == widget.facility.ownerAccountId;

  bool get _canFollow =>
      AuthService().isAuthenticated &&
      !_isOwner &&
      widget.facility.ownerAccountId != null;

  int get _upcomingCount {
    final now = DateTime.now();
    return _events.where((e) => !(e.endDate ?? e.startDate).isBefore(now)).length;
  }

  Future<void> _loadEvents() async {
    setState(() => _eventsLoading = true);
    try {
      final events =
          await ApiService().getEventsForFacility(widget.facility.id);
      if (mounted) setState(() => _events = events);
    } catch (_) {}
    if (mounted) setState(() => _eventsLoading = false);
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final following = await ApiService().checkFollowing(widget.facility.ownerAccountId!);
      if (mounted) setState(() => _isSubscribed = following);
    } catch (_) {
      if (mounted) setState(() => _isSubscribed = false);
    }
  }

  Future<void> _toggleSubscription() async {
    if (_isSubscribed == null) return;
    final was = _isSubscribed!;
    setState(() => _isSubscribed = !was);
    try {
      if (was) {
        await ApiService().unfollowUser(widget.facility.ownerAccountId!);
      } else {
        await ApiService().followUser(widget.facility.ownerAccountId!);
      }
    } catch (_) {
      if (mounted) setState(() => _isSubscribed = was);
    }
  }

  Future<void> _editEvent(int index) async {
    final updated = await Navigator.of(context).push<Event>(
      MaterialPageRoute(
          builder: (_) => EventFormPage(
                existing: _events[index],
                availableWalls: _walls,
              )),
    );
    if (updated != null && mounted) {
      setState(() => _events[index] = updated);
    }
  }

  Future<void> _createEvent() async {
    final newEvent = await Navigator.of(context).push<Event>(
      MaterialPageRoute(
          builder: (_) => EventFormPage(
                availableWalls: _walls,
              )),
    );
    if (newEvent != null && mounted) {
      _loadEvents();
      widget.onChanged?.call();
    }
  }

  Future<void> _deleteEvent(int index) async {
    final event = _events[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('Delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().deleteEvent(event.id);
      if (mounted) setState(() => _events.removeAt(index));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> _closeEvent(int index) async {
    final event = _events[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close event?'),
        content: Text('Close "${event.title}" and distribute badges?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Close Event'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().closeEvent(event.id);
      _loadEvents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event closed and badges distributed!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to close event: $e')));
    }
  }

  void _viewLeaderboard(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventLeaderboardPage(event: _events[index]),
      ),
    );
  }

  void _manageBadges(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManageEventBadgesPage(event: _events[index]),
      ),
    );
  }

  Widget _buildEventsTab() {
    final now = DateTime.now();
    final upcoming = <Event>[];
    final past = <Event>[];
    for (var i = 0; i < _events.length; i++) {
      final e = _events[i];
      if ((e.endDate ?? e.startDate).isBefore(now)) {
        past.add(e);
      } else {
        upcoming.add(e);
      }
    }

    if (_events.isEmpty) {
      return const Center(child: Text('No events.'));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (_isOwner)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: _createEvent,
              icon: const Icon(Icons.add),
              label: const Text('Create New Event'),
            ),
          ),
        if (upcoming.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No upcoming events.', textAlign: TextAlign.center),
          )
        else
          ...upcoming.map((e) {
            final i = _events.indexOf(e);
            return _EventTile(
              event: e,
              isOwner: _isOwner,
              onEdit: () => _editEvent(i),
              onDelete: () => _deleteEvent(i),
              onClose: () => _closeEvent(i),
              onManageBadges: () => _manageBadges(i),
              onViewLeaderboard: () => _viewLeaderboard(i),
            );
          }),
        if (past.isNotEmpty)
          ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: const Icon(Icons.history),
            title: Text('Past events (${past.length})'),
            children: past.map((e) {
              final i = _events.indexOf(e);
              return _EventTile(
                event: e,
                isPast: true,
                isOwner: _isOwner,
                onEdit: () => _editEvent(i),
                onDelete: () => _deleteEvent(i),
                onClose: () => _closeEvent(i),
                onManageBadges: () => _manageBadges(i),
              onViewLeaderboard: () => _viewLeaderboard(i),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _showCreateWallDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateWallDialog(),
    );
    if (ok == true && mounted) {
      widget.onChanged?.call();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Wall created')));
    }
  }

  Future<void> _showEditWallDialog(int index) async {
    final wall = _walls[index];
    final result = await showDialog<
        ({String name, String description, String difficulty})>(
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
        _walls[index] = IndoorWallSummary(
          id: wall.id,
          name: result.name,
          description: result.description,
          difficulty: result.difficulty,
          rating: wall.rating,
          status: wall.status,
        );
      });
      widget.onChanged?.call();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Wall updated')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update wall')));
    }
  }

  Future<void> _confirmDeleteWall(int index) async {
    final wall = _walls[index];
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete wall?'),
        content: Text(
            'This will permanently delete "${wall.name}". This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ApiService().deleteWall(wall.id);
    if (!mounted) return;

    if (ok) {
      setState(() => _walls.removeAt(index));
      widget.onChanged?.call();
      messenger.showSnackBar(const SnackBar(content: Text('Wall deleted')));
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text('Failed to delete wall')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        width: double.infinity,
        child: Material(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.domain, color: cs.primary, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.facility.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_canFollow)
                          _isSubscribed == null
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  tooltip: _isSubscribed!
                                      ? 'Unfollow gym'
                                      : 'Follow gym',
                                  icon: Icon(
                                    _isSubscribed!
                                        ? Icons.add_circle
                                        : Icons.add,
                                    color: _isSubscribed! ? cs.primary : null,
                                  ),
                                  onPressed: _toggleSubscription,
                                ),
                        if (_isOwner)
                          IconButton(
                            tooltip: 'Add wall',
                            onPressed: _showCreateWallDialog,
                            icon: const Icon(Icons.add_circle_outline),
                            color: cs.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Chip(
                      label: Text(
                        'Indoor Facility',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      backgroundColor: Colors.blueGrey,
                    ),
                    if (widget.facility.address != null &&
                        widget.facility.address!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on,
                              size: 18,
                              color: Theme.of(context).iconTheme.color),
                          const SizedBox(width: 6),
                          Expanded(child: Text(widget.facility.address!)),
                        ],
                      ),
                    ],
                    if (widget.facility.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.facility.description,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              // ── Tabs ─────────────────────────────────────────────────
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Walls (${_walls.length})'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Events'),
                        if (_upcomingCount > 0) ...[
                          const SizedBox(width: 6),
                          Badge(label: Text('$_upcomingCount')),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // ── Tab content ───────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Walls tab
                    _walls.isEmpty
                        ? const Center(
                            child: Text(
                                'No walls registered for this facility yet.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _walls.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) => _WallTile(
                              wall: _walls[i],
                              isOwner: _isOwner,
                              onEdit: () => _showEditWallDialog(i),
                              onDelete: () => _confirmDeleteWall(i),
                            ),
                          ),
                    // Events tab
                    _eventsLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildEventsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Event tile ───────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
    required this.onManageBadges,
    required this.onViewLeaderboard,
    this.isPast = false,
  });

  final Event event;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  final VoidCallback onManageBadges;
  final VoidCallback onViewLeaderboard;
  final bool isPast;

  String _formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isOngoing = !isPast &&
        !event.startDate.isAfter(now) &&
        (event.endDate == null || event.endDate!.isAfter(now));

    final dateLabel = event.endDate != null
        ? '${_formatDate(event.startDate)} – ${_formatDate(event.endDate!)}'
        : _formatDate(event.startDate);

    Widget? trailing;
    
    final viewLeaderboardBtn = IconButton(
      icon: const Icon(Icons.leaderboard_outlined, size: 20),
      tooltip: 'View Leaderboard',
      onPressed: onViewLeaderboard,
      visualDensity: VisualDensity.compact,
    );

    if (isOwner) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOngoing) _BlinkingDot(color: cs.primary),
          viewLeaderboardBtn,
          IconButton(
            icon: const Icon(Icons.military_tech, size: 20),
            tooltip: 'Manage Badges',
            onPressed: onManageBadges,
            visualDensity: VisualDensity.compact,
          ),
          if (event.status != 'closed') ...[
            if (!isPast)
              IconButton(
                icon: Icon(Icons.check_circle_outline, size: 20, color: cs.primary),
                tooltip: 'Close Event',
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
              tooltip: 'Delete',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOngoing) _BlinkingDot(color: cs.primary),
          viewLeaderboardBtn,
        ],
      );
    }


    return Card(
      elevation: 0,
      color: isPast
          ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
          : cs.surfaceContainerHighest,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isOngoing ? cs.primary : cs.secondaryContainer,
          child: Icon(
            Icons.event,
            color: isOngoing ? cs.onPrimary : cs.onSecondaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          event.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isPast
                ? cs.onSurface.withValues(alpha: 0.5)
                : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            if (event.description != null && event.description!.isNotEmpty)
              Text(
                event.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
          ],
        ),
        trailing: trailing,
        isThreeLine:
            event.description != null && event.description!.isNotEmpty,
      ),
    );
  }
}

// ─── Blinking live dot ───────────────────────────────────────────────────────

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({this.color});
  final Color? color;

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

// ─── Wall tile ────────────────────────────────────────────────────────────────

class _WallTile extends StatelessWidget {
  final IndoorWallSummary wall;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _WallTile({
    required this.wall,
    required this.isOwner,
    this.onEdit,
    this.onDelete,
  });

  Color _difficultyColor(String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'BEGINNER':
        return Colors.green;
      case 'INTERMEDIATE':
        return Colors.amber;
      case 'ADVANCED':
        return Colors.orange;
      case 'EXPERT':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openWallDetails(BuildContext context) async {
    final Wall? full = await ApiService().getWallById(wall.id);
    if (full == null || !context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => WallDetailsDialog(wall: full),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOpen = wall.status == 'OPEN';

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _difficultyColor(wall.difficulty),
          child: const Icon(Icons.route, color: Colors.white, size: 18),
        ),
        title: Text(wall.name),
        subtitle: Row(
          children: [
            Text(wall.difficulty),
            const SizedBox(width: 8),
            if (!isOpen)
              Chip(
                label: Text(
                  wall.status.replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 10),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.orange.shade100,
              ),
          ],
        ),
        trailing: isOwner
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (wall.rating > 0) ...[
                    Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 2),
                    Text(wall.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: colorScheme.error),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              )
            : wall.rating > 0
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 2),
                      Text(wall.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 13)),
                    ],
                  )
                : null,
        onTap: () => _openWallDetails(context),
      ),
    );
  }
}

// ─── Create wall dialog ───────────────────────────────────────────────────────

class _CreateWallDialog extends StatefulWidget {
  const _CreateWallDialog();

  @override
  State<_CreateWallDialog> createState() => _CreateWallDialogState();
}

class _CreateWallDialogState extends State<_CreateWallDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _difficulty = 'UNKNOWN';
  bool _saving = false;

  static const _difficultyOptions = [
    'UNKNOWN',
    'BEGINNER',
    'INTERMEDIATE',
    'ADVANCED',
    'EXPERT',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    setState(() => _saving = true);
    final ok = await ApiService().createWall(
      name: name,
      description: _descCtrl.text.trim(),
      difficulty: _difficulty,
    );
    if (!mounted) return;
    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Add indoor wall'),
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
              items: _difficultyOptions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _difficulty = v);
                    },
            ),
            const SizedBox(height: 8),
            Text(
              'The wall will be placed at your facility\'s location.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ─── Edit wall dialog ─────────────────────────────────────────────────────────

class _EditWallDialog extends StatefulWidget {
  const _EditWallDialog({required this.wall});

  final IndoorWallSummary wall;

  @override
  State<_EditWallDialog> createState() => _EditWallDialogState();
}

class _EditWallDialogState extends State<_EditWallDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String _difficulty;

  static const _difficultyOptions = [
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
    _difficulty =
        _difficultyOptions.contains(widget.wall.difficulty.toUpperCase())
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
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
              items: _difficultyOptions
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
        FilledButton(
          onPressed: _confirm,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
