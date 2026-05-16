import 'package:flutter/material.dart';

import '../models/poi.dart';
import '../models/wall.dart';
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

class _FacilityDetailsDialogState extends State<FacilityDetailsDialog> {
  late List<IndoorWallSummary> _walls;

  @override
  void initState() {
    super.initState();
    _walls = List.of(widget.facility.walls);
  }

  bool get _isOwner =>
      AuthService().userType == 'FacilityOwner' &&
      widget.facility.ownerAccountId != null &&
      AuthService().currentUserId == widget.facility.ownerAccountId;

  Future<void> _showCreateDialog() async {
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

  Future<void> _showEditDialog(int index) async {
    final wall = _walls[index];
    final result = await showDialog<({String name, String description, String difficulty})>(
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to update wall')));
    }
  }

  Future<void> _confirmDelete(int index) async {
    final wall = _walls[index];
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete wall?'),
        content: Text('This will permanently delete "${wall.name}". This cannot be undone.'),
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
      messenger.showSnackBar(const SnackBar(content: Text('Failed to delete wall')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.80,
        width: double.infinity,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.domain, color: Colors.blueGrey, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.facility.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_isOwner)
                      IconButton(
                        tooltip: 'Add wall',
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add_circle_outline),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Chip(
                  label: Text(
                    'Indoor Facility',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: Colors.blueGrey,
                ),
                if (widget.facility.address != null &&
                    widget.facility.address!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(widget.facility.address!)),
                    ],
                  ),
                ],
                if (widget.facility.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.facility.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Climbing Walls (${_walls.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _walls.isEmpty
                      ? const Center(
                          child: Text(
                            'No walls registered for this facility yet.',
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _walls.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            return _WallTile(
                              wall: _walls[i],
                              isOwner: _isOwner,
                              onEdit: () => _showEditDialog(i),
                              onDelete: () => _confirmDelete(i),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
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
                    Text(
                      wall.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13),
                    ),
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
                    icon: Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
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
                      Text(
                        wall.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13),
                      ),
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
    'UNKNOWN', 'BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'EXPERT',
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
              onChanged: _saving ? null : (v) { if (v != null) setState(() => _difficulty = v); },
            ),
            const SizedBox(height: 8),
            Text(
              'The wall will be placed at your facility\'s location.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    'UNKNOWN', 'BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'EXPERT',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.wall.name);
    _descCtrl = TextEditingController(text: widget.wall.description);
    _difficulty = _difficultyOptions.contains(widget.wall.difficulty.toUpperCase())
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
              onChanged: (v) { if (v != null) setState(() => _difficulty = v); },
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
