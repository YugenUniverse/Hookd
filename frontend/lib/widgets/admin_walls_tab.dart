import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/poi.dart';
import '../models/user.dart';

class AdminWallsTab extends StatefulWidget {
  const AdminWallsTab({super.key});

  @override
  State<AdminWallsTab> createState() => _AdminWallsTabState();
}

class _AdminWallsTabState extends State<AdminWallsTab> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<WallAdminSummary> _walls = [];
  List<User> _publicBodies = [];

  @override
  void initState() {
    super.initState();
    _loadPublicBodies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPublicBodies() async {
    try {
      final bodies = await ApiService().getPublicBodies();
      if (mounted) setState(() => _publicBodies = bodies);
    } catch (e) {
      print('Error loading public bodies: $e');
    }
  }

  Future<void> _searchWalls(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _walls = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final walls = await ApiService().searchWalls(query);
      if (mounted) setState(() => _walls = walls);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching walls: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWall(WallAdminSummary wall) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Wall'),
        content: Text('Are you sure you want to delete ${wall.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await ApiService().deleteWall(wall.id);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wall deleted')));
          _searchWalls(_searchController.text);
        }
      } else {
        throw Exception('Delete failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting wall: $e')));
      }
    }
  }

  Future<void> _showWallDialog({WallAdminSummary? wall}) async {
    final nameCtrl = TextEditingController(text: wall?.name ?? '');
    final descCtrl = TextEditingController(text: wall?.description ?? '');
    String difficulty = wall?.difficulty ?? 'UNKNOWN';
    String status = wall?.status ?? 'OPEN';
    String? selectedPublicBodyId;

    final formKey = GlobalKey<FormState>();

    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(wall == null ? 'Create Outdoor Wall' : 'Edit Wall'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (wall == null) ...[
                        DropdownButtonFormField<String>(
                          value: selectedPublicBodyId,
                          decoration: const InputDecoration(labelText: 'Assign to Public Body'),
                          items: _publicBodies.map((pb) {
                            return DropdownMenuItem(
                              value: pb.id,
                              child: Text(pb.name ?? pb.username),
                            );
                          }).toList(),
                          onChanged: (v) => setStateDialog(() => selectedPublicBodyId = v),
                          validator: (v) => v == null ? 'Please select a Public Body' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Wall Name'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: difficulty,
                        decoration: const InputDecoration(labelText: 'Difficulty'),
                        items: const [
                          DropdownMenuItem(value: 'UNKNOWN', child: Text('Unknown')),
                          DropdownMenuItem(value: 'BEGINNER', child: Text('Beginner')),
                          DropdownMenuItem(value: 'INTERMEDIATE', child: Text('Intermediate')),
                          DropdownMenuItem(value: 'ADVANCED', child: Text('Advanced')),
                          DropdownMenuItem(value: 'EXPERT', child: Text('Expert')),
                        ],
                        onChanged: (v) => setStateDialog(() => difficulty = v!),
                      ),
                      if (wall != null) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                            DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
                            DropdownMenuItem(value: 'UNDER_MAINTAINANCE', child: Text('Under Maintenance')),
                            DropdownMenuItem(value: 'PERMANENTLY_CLOSED', child: Text('Permanently Closed')),
                          ],
                          onChanged: (v) => setStateDialog(() => status = v!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    bool ok = false;
                    if (wall == null) {
                      ok = await ApiService().createWall(
                        name: nameCtrl.text,
                        description: descCtrl.text,
                        difficulty: difficulty,
                        publicBodyId: selectedPublicBodyId,
                        longitude: 0, // Mock location for demo
                        latitude: 0,
                      );
                    } else {
                      ok = await ApiService().updateWall(
                        wall.id,
                        name: nameCtrl.text,
                        description: descCtrl.text,
                        difficulty: difficulty,
                        status: status,
                      );
                    }
                    Navigator.pop(ctx, ok);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (success == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully')));
        _searchWalls(_searchController.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search Walls',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: _searchWalls,
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _showWallDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Wall'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _walls.isEmpty
                  ? const Center(child: Text('No walls found'))
                  : ListView.builder(
                      itemCount: _walls.length,
                      itemBuilder: (context, index) {
                        final wall = _walls[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(wall.name),
                            subtitle: Text('${wall.wallType} - ${wall.status}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showWallDialog(wall: wall),
                                ),
                                if (wall.wallType == 'OutdoorWall')
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteWall(wall),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
