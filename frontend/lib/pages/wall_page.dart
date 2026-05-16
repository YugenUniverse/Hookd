import 'package:flutter/material.dart';
import '../services/wall_service.dart';
import '../models/wall.dart';
import '../dialogs/wall_details_dialog.dart';

class WallsPage extends StatefulWidget {
  const WallsPage({super.key});

  @override
  State<WallsPage> createState() => _WallsScreenState();
}

class _WallsScreenState extends State<WallsPage> {
  final WallService _wallService = WallService();
  late Future<List<Wall>> _wallsFuture;

  @override
  void initState() {
    super.initState();
    _wallsFuture = _wallService.fetchAllWalls();
  }

  void _refresh() {
    setState(() {
      _wallsFuture = _wallService.fetchAllWalls();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Climbing Walls')),
      body: FutureBuilder<List<Wall>>(
        future: _wallsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 44,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load walls',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.landscape,
                      size: 56,
                      color: colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No walls found',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'There are no climbing walls available.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final walls = snapshot.data!;
          return ListView.builder(
            itemCount: walls.length,
            itemBuilder: (context, index) {
              final wall = walls[index];

              IconData wallIcon = wall.wallType == 'IndoorWall'
                  ? Icons.domain
                  : Icons.landscape;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    wallIcon,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    wall.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${wall.wallType == 'IndoorWall' ? 'Indoor' : 'Outdoor'} • ${wall.difficulty} • By ${wall.ownerName}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return WallDetailsDialog(wall: wall);
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
