import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/calendar_helper.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/group.dart';
import '../models/poi.dart';
import '../providers/group_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  late Future<Group> _groupFuture;
  List<PlannedClimb> _climbs = [];
  bool _climbsLoading = false;

  @override
  void initState() {
    super.initState();
    _groupFuture = ApiService().getGroupById(widget.groupId);
    _loadClimbs();
  }

  Future<void> _loadClimbs() async {
    setState(() => _climbsLoading = true);
    try {
      final climbs = await ApiService().getPlannedClimbs(widget.groupId);
      if (mounted) setState(() => _climbs = climbs);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _climbsLoading = false);
    }
  }

  void _refresh() {
    setState(() {
      _groupFuture = ApiService().getGroupById(widget.groupId);
    });
    _loadClimbs();
  }

  bool _isAdmin(Group group, String userId) =>
      group.members.any((m) => m.userId == userId && m.isAdmin);

  Future<void> _inviteUser(Group group) async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite climber'),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'e.g. alex_climbs',
            prefixText: '@',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (username == null || username.isEmpty || !mounted) return;

    final ok = await context.read<GroupProvider>().inviteUser(group.id, username);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Invitation sent!' : 'User not found or invite already sent.'),
    ));
  }

  Future<void> _removeMember(Group group, GroupMember member) async {
    final currentUserId = AuthService().currentUserId ?? '';
    final isSelf = member.userId == currentUserId;
    final displayName = member.name ?? member.username ?? member.userId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isSelf ? 'Leave group?' : 'Remove member?'),
        content: Text(
          isSelf
              ? 'Are you sure you want to leave "${group.name}"?'
              : 'Remove $displayName from "${group.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isSelf ? 'Leave' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context.read<GroupProvider>().leaveOrRemoveMember(
          group.id,
          member.userId,
        );
    if (!mounted) return;
    if (ok) {
      if (isSelf) {
        Navigator.of(context).pop();
      } else {
        _refresh();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operation failed. Please try again.')),
      );
    }
  }

  Future<void> _leaveGroup(Group group, String currentUserId) async {
    final isAdmin = _isAdmin(group, currentUserId);
    final others = group.members.where((m) => m.userId != currentUserId).toList();

    if (isAdmin && others.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot leave'),
          content: Text('You are the only member of "${group.name}". Delete the group instead.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    String content = 'Are you sure you want to leave "${group.name}"?';
    if (isAdmin && others.every((m) => !m.isAdmin)) {
      final earliest = (others.toList()
            ..sort((a, b) => (a.joinedAt ?? DateTime(0))
                .compareTo(b.joinedAt ?? DateTime(0))))
          .first;
      final name = earliest.name ?? earliest.username ?? 'another member';
      content += '\n\n$name will become the new admin.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group?'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context
        .read<GroupProvider>()
        .leaveOrRemoveMember(group.id, currentUserId);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not leave group. Please try again.')),
      );
    }
  }

  Future<void> _deleteGroup(Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('This will permanently delete "${group.name}" and all its data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context.read<GroupProvider>().deleteGroup(group.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete group.')),
      );
    }
  }

  Future<void> _addPlannedClimb() async {
    final result = await showDialog<({DateTime date, String? venueId, String? venueType, String? notes})>(
      context: context,
      builder: (ctx) => const _AddClimbDialog(),
    );
    if (result == null || !mounted) return;

    try {
      final climb = await ApiService().createPlannedClimb(
        widget.groupId,
        date: result.date,
        venueId: result.venueId,
        venueType: result.venueType,
        notes: result.notes,
      );
      if (mounted) {
        setState(() {
          _climbs = [..._climbs, climb]..sort((a, b) => a.date.compareTo(b.date));
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add planned climb.')),
      );
    }
  }

  Future<void> _deletePlannedClimb(PlannedClimb climb) async {
    try {
      await ApiService().deletePlannedClimb(widget.groupId, climb.id);
      if (mounted) setState(() => _climbs.removeWhere((c) => c.id == climb.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete planned climb.')),
      );
    }
  }

  Future<void> _rsvpClimb(PlannedClimb climb, String status) async {
    try {
      final updated = await ApiService().rsvpPlannedClimb(widget.groupId, climb.id, status);
      if (mounted) {
        setState(() {
          final idx = _climbs.indexWhere((c) => c.id == climb.id);
          if (idx >= 0) _climbs[idx] = updated;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update RSVP.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId = AuthService().currentUserId ?? '';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.surface, cs.surfaceContainerHighest.withValues(alpha: 0.85)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<Group>(
          future: _groupFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Group')),
                body: Center(child: Text('Error: ${snapshot.error}')),
              );
            }

            final group = snapshot.data!;
            final isAdmin = _isAdmin(group, currentUserId);
            final isSolo = group.members.length == 1;

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                title: Text(group.name),
                actions: [
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.person_add_outlined),
                      tooltip: 'Invite',
                      onPressed: () => _inviteUser(group),
                    ),
                  if (!isSolo)
                    IconButton(
                      icon: const Icon(Icons.exit_to_app),
                      tooltip: 'Leave group',
                      onPressed: () => _leaveGroup(group, currentUserId),
                    ),
                  if (isAdmin)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: cs.error),
                      tooltip: 'Delete group',
                      onPressed: () => _deleteGroup(group),
                    ),
                ],
              ),
              floatingActionButton: isAdmin
                  ? FloatingActionButton.extended(
                      onPressed: _addPlannedClimb,
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Plan a climb'),
                    )
                  : null,
              body: RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    if (group.description != null && group.description!.isNotEmpty) ...[
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
                        ),
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(group.description!),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ─── Planned Climbs ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Planned Climbs',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (_climbsLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (_climbs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25)),
                          ),
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Icon(Icons.hiking_outlined, color: cs.onSurfaceVariant, size: 28),
                                const SizedBox(width: 12),
                                Text(
                                  isAdmin
                                      ? 'No climbs planned yet. Tap "Plan a climb" to add one.'
                                      : 'No climbs planned yet.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ..._climbs.map((climb) => _PlannedClimbTile(
                            climb: climb,
                            groupName: group.name,
                            isAdmin: isAdmin,
                            currentUserId: currentUserId,
                            onDelete: () => _deletePlannedClimb(climb),
                            onRsvp: (status) => _rsvpClimb(climb, status),
                          )),

                    const SizedBox(height: 16),

                    // ─── Members ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Members (${group.members.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    ...group.members.map((member) => _MemberTile(
                          member: member,
                          currentUserId: currentUserId,
                          isCurrentUserAdmin: isAdmin,
                          onRemove: () => _removeMember(group, member),
                        )),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Add Climb Dialog ─────────────────────────────────────────────────────────

class _AddClimbDialog extends StatefulWidget {
  const _AddClimbDialog();

  @override
  State<_AddClimbDialog> createState() => _AddClimbDialogState();
}

class _AddClimbDialogState extends State<_AddClimbDialog> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Poi? _selectedVenue;
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  List<Poi> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearching = true);
      final results = await ApiService().searchPois(query.trim());
      if (mounted) setState(() { _searchResults = results; _isSearching = false; });
    });
  }

  void _selectVenue(Poi poi) {
    setState(() {
      _selectedVenue = poi;
      _searchResults = [];
      _searchController.clear();
    });
  }

  void _clearVenue() {
    setState(() {
      _selectedVenue = null;
      _searchResults = [];
    });
  }

  String _formatDate(DateTime d) => DateFormat('EEE, MMM d, yyyy').format(d);
  String _formatTime(TimeOfDay t) => t.format(context);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Plan a climb'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date (required)
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _selectedDate == null ? 'Pick a date *' : _formatDate(_selectedDate!),
                  style: _selectedDate == null ? TextStyle(color: cs.onSurfaceVariant) : null,
                ),
              ),
              const SizedBox(height: 8),
              // Time (optional)
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time_outlined),
                label: Text(
                  _selectedTime == null ? 'Pick a time (optional)' : _formatTime(_selectedTime!),
                  style: _selectedTime == null ? TextStyle(color: cs.onSurfaceVariant) : null,
                ),
              ),
              const SizedBox(height: 12),

              // Venue search
              if (_selectedVenue != null)
                _SelectedVenueTile(venue: _selectedVenue!, onClear: _clearVenue)
              else ...[
                TextField(
                  controller: _searchController,
                  autofocus: false,
                  autocorrect: false,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    labelText: 'Search wall or gym',
                    hintText: 'e.g. Arco Slab, Rock Palace...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (ctx, i) {
                        final poi = _searchResults[i];
                        final isLast = i == _searchResults.length - 1;
                        final isGym = poi is FacilityPoi;
                        return InkWell(
                          onTap: () => _selectVenue(poi),
                          borderRadius: BorderRadius.vertical(
                            top: i == 0 ? const Radius.circular(12) : Radius.zero,
                            bottom: isLast ? const Radius.circular(12) : Radius.zero,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  isGym ? Icons.fitness_center_outlined : Icons.terrain_outlined,
                                  size: 18,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(poi.name, style: theme.textTheme.bodyMedium),
                                ),
                                Text(
                                  isGym ? 'Gym' : 'Outdoor',
                                  style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],

              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Bring slippers, meet at the car park...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedDate == null
              ? null
              : () {
                  var date = _selectedDate!;
                  if (_selectedTime != null) {
                    date = DateTime(date.year, date.month, date.day, _selectedTime!.hour, _selectedTime!.minute);
                  }
                  final notes = _notesController.text.trim();
                  Navigator.of(context).pop((
                    date: date,
                    venueId: _selectedVenue?.id,
                    venueType: _selectedVenue is FacilityPoi ? 'Facility' : (_selectedVenue != null ? 'Wall' : null),
                    notes: notes.isEmpty ? null : notes,
                  ));
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _SelectedVenueTile extends StatelessWidget {
  const _SelectedVenueTile({required this.venue, required this.onClear});
  final Poi venue;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isGym = venue is FacilityPoi;
    return Container(
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isGym ? Icons.fitness_center_outlined : Icons.terrain_outlined,
          color: cs.onSecondaryContainer,
        ),
        title: Text(venue.name, style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600)),
        subtitle: Text(isGym ? 'Gym' : 'Outdoor wall', style: TextStyle(color: cs.onSecondaryContainer.withValues(alpha: 0.7))),
        trailing: IconButton(
          icon: Icon(Icons.close, color: cs.onSecondaryContainer, size: 18),
          onPressed: onClear,
        ),
      ),
    );
  }
}

// ─── Planned Climb Tile ───────────────────────────────────────────────────────

class _PlannedClimbTile extends StatelessWidget {
  const _PlannedClimbTile({
    required this.climb,
    required this.groupName,
    required this.isAdmin,
    required this.currentUserId,
    required this.onDelete,
    required this.onRsvp,
  });

  final PlannedClimb climb;
  final String groupName;
  final bool isAdmin;
  final String currentUserId;
  final VoidCallback onDelete;
  final void Function(String status) onRsvp;

  void _addToCalendar() {
    final title = climb.wallName != null && climb.wallName!.isNotEmpty
        ? '$groupName @ ${climb.wallName}'
        : '$groupName – Group climb';
    addClimbToCalendar(
      title: title,
      start: climb.date.toLocal(),
      location: climb.wallName ?? '',
      description: climb.notes ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasTime = climb.date.hour != 0 || climb.date.minute != 0;
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(climb.date.toLocal());
    final timeStr = hasTime ? DateFormat('HH:mm').format(climb.date.toLocal()) : null;

    final myAttendee = climb.attendees.where((a) => a.userId == currentUserId).firstOrNull;
    final myStatus = myAttendee?.status; // "going", "not_going", or null

    final goingCount = climb.attendees.where((a) => a.status == 'going').length;
    final notGoingCount = climb.attendees.where((a) => a.status == 'not_going').length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.terrain_outlined, color: cs.onTertiaryContainer, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(dateStr, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          if (timeStr != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(timeStr, style: theme.textTheme.labelSmall?.copyWith(color: cs.onSecondaryContainer)),
                            ),
                          ],
                        ],
                      ),
                      if (climb.wallName != null && climb.wallName!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                climb.wallName!,
                                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (climb.notes != null && climb.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(climb.notes!, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today_outlined, size: 18, color: cs.onSurfaceVariant),
                  tooltip: 'Add to calendar',
                  onPressed: _addToCalendar,
                  visualDensity: VisualDensity.compact,
                ),
                if (isAdmin)
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                    tooltip: 'Remove',
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Attendee counts
                if (climb.attendees.isNotEmpty) ...[
                  Icon(Icons.check_circle_outline, size: 14, color: cs.primary),
                  const SizedBox(width: 3),
                  Text('$goingCount', style: theme.textTheme.labelSmall?.copyWith(color: cs.primary)),
                  const SizedBox(width: 8),
                  Icon(Icons.cancel_outlined, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text('$notGoingCount', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  const Spacer(),
                ] else
                  const Spacer(),
                // RSVP buttons
                _RsvpButton(
                  label: 'Going',
                  icon: Icons.check,
                  selected: myStatus == 'going',
                  onTap: () => onRsvp('going'),
                ),
                const SizedBox(width: 6),
                _RsvpButton(
                  label: 'Not going',
                  icon: Icons.close,
                  selected: myStatus == 'not_going',
                  onTap: () => onRsvp('not_going'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    if (selected) {
      return FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: theme.textTheme.labelSmall,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: theme.textTheme.labelSmall,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        foregroundColor: cs.onSurfaceVariant,
        side: BorderSide(color: cs.outlineVariant),
      ),
    );
  }
}

// ─── Member Tile ──────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.currentUserId,
    required this.isCurrentUserAdmin,
    required this.onRemove,
  });

  final GroupMember member;
  final String currentUserId;
  final bool isCurrentUserAdmin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isSelf = member.userId == currentUserId;
    final displayName = member.name ?? member.username ?? member.userId;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final canAct = isCurrentUserAdmin && !isSelf;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            initial,
            style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          displayName,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: member.username != null && member.name != null
            ? Text('@${member.username}', style: theme.textTheme.bodySmall)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (member.isAdmin)
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
            if (canAct) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: cs.error),
                tooltip: 'Remove member',
                onPressed: onRemove,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
