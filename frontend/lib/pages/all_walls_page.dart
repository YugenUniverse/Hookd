import 'package:flutter/material.dart';

import '../models/poi.dart' show IndoorWallSummary;
import '../services/api_service.dart';

class AllWallsPage extends StatefulWidget {
  const AllWallsPage({
    super.key,
    required this.title,
    required this.walls,
    this.canDelete = false,
  });

  final String title;
  final List<IndoorWallSummary> walls;
  final bool canDelete;

  @override
  State<AllWallsPage> createState() => _AllWallsPageState();
}

class _AllWallsPageState extends State<AllWallsPage> {
  late List<IndoorWallSummary> _walls;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _walls = List.of(widget.walls);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onUpdated(int index, IndoorWallSummary updated) {
    setState(() => _walls[index] = updated);
  }

  void _onDeleted(int index) {
    setState(() => _walls.removeAt(index));
  }

  List<IndoorWallSummary> get _filtered => _query.isEmpty
      ? _walls
      : _walls
          .where((w) => w.name.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (q) => setState(() => _query = q),
              decoration: InputDecoration(
                hintText: 'Search walls…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} wall${filtered.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty ? 'No walls.' : 'No walls match "$_query".',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final wall = filtered[index];
                      final realIndex = _walls.indexOf(wall);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WallTile(
                          wall: wall,
                          canDelete: widget.canDelete,
                          onUpdated: (updated) => _onUpdated(realIndex, updated),
                          onDeleted: () => _onDeleted(realIndex),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _WallTile extends StatelessWidget {
  const _WallTile({
    required this.wall,
    required this.canDelete,
    required this.onUpdated,
    required this.onDeleted,
  });

  final IndoorWallSummary wall;
  final bool canDelete;
  final void Function(IndoorWallSummary updated) onUpdated;
  final VoidCallback onDeleted;

  Color _difficultyColor(String d) => switch (d.toUpperCase()) {
        'BEGINNER' => Colors.green,
        'INTERMEDIATE' => Colors.amber.shade700,
        'ADVANCED' => Colors.orange,
        'EXPERT' => Colors.red.shade700,
        _ => Colors.grey,
      };

  Future<void> _showEditDialog(BuildContext context) async {
    final result = await showDialog<({String name, String description, String difficulty})>(
      context: context,
      builder: (_) => _EditWallDialog(wall: wall),
    );
    if (result == null || !context.mounted) return;

    final ok = await ApiService().updateWall(
      wall.id,
      name: result.name,
      description: result.description,
      difficulty: result.difficulty,
    );
    if (!context.mounted) return;

    if (ok) {
      onUpdated(IndoorWallSummary(
        id: wall.id,
        name: result.name,
        description: result.description,
        difficulty: result.difficulty,
        rating: wall.rating,
        status: wall.status,
      ));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Wall updated')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to update wall')));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete wall?'),
        content: Text(
          'This will permanently delete "${wall.name}". This cannot be undone.',
        ),
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
    if (!context.mounted) return;

    if (ok) {
      onDeleted();
      messenger.showSnackBar(const SnackBar(content: Text('Wall deleted')));
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to delete wall')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isOpen = wall.status.toUpperCase() == 'OPEN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _difficultyColor(wall.difficulty),
            child: Icon(
              canDelete ? Icons.landscape : Icons.route,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wall.name,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      wall.difficulty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (!isOpen) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          wall.status.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (wall.rating > 0) ...[
            Icon(Icons.star, size: 14, color: Colors.amber.shade700),
            const SizedBox(width: 2),
            Text(
              wall.rating.toStringAsFixed(1),
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            tooltip: 'Edit wall',
            onPressed: () => _showEditDialog(context),
            icon: const Icon(Icons.edit_outlined),
          ),
          if (canDelete)
            IconButton(
              tooltip: 'Delete wall',
              onPressed: () => _confirmDelete(context),
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
            ),
        ],
      ),
    );
  }
}

class _EditWallDialog extends StatefulWidget {
  const _EditWallDialog({required this.wall});

  final IndoorWallSummary wall;

  @override
  State<_EditWallDialog> createState() => _EditWallDialogState();
}

class _EditWallDialogState extends State<_EditWallDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
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
    _nameController = TextEditingController(text: widget.wall.name);
    _descriptionController =
        TextEditingController(text: widget.wall.description);
    _difficulty = _difficultyOptions.contains(widget.wall.difficulty.toUpperCase())
        ? widget.wall.difficulty.toUpperCase()
        : 'UNKNOWN';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }
    Navigator.of(context).pop((
      name: name,
      description: _descriptionController.text.trim(),
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
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
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
