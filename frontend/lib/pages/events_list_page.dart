import 'package:flutter/material.dart';
import 'event_leaderboard_page.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/poi.dart';
import '../services/api_service.dart';
import 'manage_event_badges_page.dart';

class EventsListPage extends StatefulWidget {
  const EventsListPage({
    super.key,
    required this.facilityId,
    required this.facilityName,
    this.availableWalls = const [],
    this.canCreate = false,
  });

  final String facilityId;
  final String facilityName;
  final List<IndoorWallSummary> availableWalls;
  final bool canCreate;

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  late Future<List<Event>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = ApiService().getEventsForFacility(widget.facilityId);
  }

  void _refresh() {
    setState(() {
      _eventsFuture = ApiService().getEventsForFacility(widget.facilityId);
    });
  }

  Future<void> _createEvent() async {
    final result = await Navigator.of(context).push<Event>(
      MaterialPageRoute(
          builder: (_) => EventFormPage(availableWalls: widget.availableWalls)),
    );
    if (result != null) _refresh();
  }

  Future<void> _editEvent(Event event) async {
    final result = await Navigator.of(context).push<Event>(
      MaterialPageRoute(
          builder: (_) => EventFormPage(
                existing: event,
                availableWalls: widget.availableWalls,
              )),
    );
    if (result != null) _refresh();
  }

  Future<void> _deleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().deleteEvent(event.id);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> _closeEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Event'),
        content: Text('Are you sure you want to close "${event.title}"? Badges will be distributed automatically and this action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close Event'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().closeEvent(event.id);
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event closed and badges distributed!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to close event: $e')));
    }
  }

  void _viewLeaderboard(Event event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventLeaderboardPage(event: event),
      ),
    );
  }

  void _manageBadges(Event event) {

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManageEventBadgesPage(event: event),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.facilityName} — Events'),
        actions: [
          if (widget.canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Create event',
              onPressed: _createEvent,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.surface, cs.surfaceContainerHighest.withValues(alpha: 0.85)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<Event>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final all = snapshot.data ?? [];
            final now = DateTime.now();
            final upcoming = all
                .where((e) => !(e.endDate ?? e.startDate).isBefore(now))
                .toList();
            final past = all
                .where((e) => (e.endDate ?? e.startDate).isBefore(now))
                .toList();

            if (all.isEmpty) {
              return const Center(child: Text('No events yet.'));
            }

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (upcoming.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No upcoming events.',
                        textAlign: TextAlign.center),
                  )
                else
                  ...upcoming.map(
                    (e) => _EventTile(
                      event: e,
                      canManage: widget.canCreate,
                      onEdit: () => _editEvent(e),
                      onDelete: () => _deleteEvent(e),
                      onClose: () => _closeEvent(e),
                      onManageBadges: () => _manageBadges(e),
                      onViewLeaderboard: () => _viewLeaderboard(e),
                    ),
                  ),
                if (past.isNotEmpty)
                  ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: const Icon(Icons.history),
                    title: Text('Past events (${past.length})'),
                    children: past
                        .map(
                          (e) => _EventTile(
                            event: e,
                            isPast: true,
                            canManage: widget.canCreate,
                            onEdit: () => _editEvent(e),
                            onDelete: () => _deleteEvent(e),
                            onClose: () {}, // Already closed
                            onManageBadges: () => _manageBadges(e),
                      onViewLeaderboard: () => _viewLeaderboard(e),
                          ),
                        )
                        .toList(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Event form page (create & edit) ─────────────────────────────────────────

class EventFormPage extends StatefulWidget {
  const EventFormPage({super.key, this.existing, this.availableWalls = const []});
  final Event? existing;
  final List<IndoorWallSummary> availableWalls;

  @override
  State<EventFormPage> createState() => EventFormPageState();
}

class EventFormPageState extends State<EventFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;
  final Set<String> _selectedWalls = {};

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _startDate = e?.startDate;
    _endDate = e?.endDate;
    if (e != null) {
      _selectedWalls.addAll(e.walls);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a start date')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final Event result;
      if (_isEdit) {
        result = await ApiService().updateEvent(
          widget.existing!.id,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          startDate: _startDate!,
          endDate: _endDate,
          walls: _selectedWalls.toList(),
        );
      } else {
        result = await ApiService().createEvent(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          startDate: _startDate!,
          endDate: _endDate,
          walls: _selectedWalls.toList(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _fmt(DateTime d) => DateFormat('d MMM yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Event' : 'Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title *'),
                maxLength: 100,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
                maxLength: 1000,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _pickDate(isStart: true),
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start date *',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(
                    _startDate != null ? _fmt(_startDate!) : 'Tap to select',
                    style: _startDate != null
                        ? null
                        : TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _pickDate(isStart: false),
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'End date (optional)',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(
                    _endDate != null ? _fmt(_endDate!) : 'Tap to select',
                    style: _endDate != null
                        ? null
                        : TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              ),
              if (widget.availableWalls.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Select Event Walls', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.availableWalls.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final wall = widget.availableWalls[index];
                      return CheckboxListTile(
                        title: Text(wall.name),
                        subtitle: Text('${wall.difficulty} • ${wall.status}'),
                        value: _selectedWalls.contains(wall.id),
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedWalls.add(wall.id);
                            } else {
                              _selectedWalls.remove(wall.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Save Changes' : 'Create Event'),
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
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
    required this.onManageBadges,
    required this.onViewLeaderboard,
    this.isPast = false,
  });

  final Event event;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  final VoidCallback onManageBadges;
  final VoidCallback onViewLeaderboard;
  final bool isPast;


  String _fmt(DateTime d) => DateFormat('d MMM yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtitle = event.endDate != null
        ? '${_fmt(event.startDate)} → ${_fmt(event.endDate!)}'
        : _fmt(event.startDate);
    return ListTile(
      leading: Icon(
        Icons.event,
        color: isPast ? cs.onSurfaceVariant.withValues(alpha: 0.5) : cs.primary,
      ),
      title: Text(
        event.title,
        style: isPast
            ? TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.7))
            : null,
      ),
      subtitle: Text(subtitle),
      trailing: canManage
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.leaderboard_outlined, size: 20),
                  tooltip: 'View Leaderboard',
                  onPressed: onViewLeaderboard,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.military_tech, size: 20),
                  tooltip: 'Manage Badges',
                  onPressed: onManageBadges,
                  visualDensity: VisualDensity.compact,
                ),
                if (event.status != 'closed') ...[
                  if (!isPast)
                    IconButton(
                      icon: Icon(Icons.check_circle_outline,
                          size: 20, color: cs.primary),
                      tooltip: 'Close Event',
                      onPressed: onClose,
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit event',
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: cs.error),
                    tooltip: 'Delete event',
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            )
          : null,


    );
  }
}
