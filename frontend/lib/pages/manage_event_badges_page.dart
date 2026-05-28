import 'package:flutter/material.dart' hide Badge;

import '../models/badge.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import 'badge_wizard_page.dart';

class ManageEventBadgesPage extends StatefulWidget {
  const ManageEventBadgesPage({super.key, required this.event});
  final Event event;

  @override
  State<ManageEventBadgesPage> createState() => _ManageEventBadgesPageState();
}

class _ManageEventBadgesPageState extends State<ManageEventBadgesPage> {
  late Future<List<Badge>> _badgesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _badgesFuture = ApiService().getBadgesForEvent(widget.event.id);
    });
  }

  Future<void> _createBadge() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BadgeWizardPage(event: widget.event),
      ),
    );
    if (result == true) {
      _refresh();
    }
  }

  Future<void> _editBadge(Badge badge) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BadgeWizardPage(
          event: widget.event,
          existingBadge: badge,
        ),
      ),
    );
    if (result == true) {
      _refresh();
    }
  }

  Future<void> _deleteBadge(Badge badge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Badge'),
        content: Text('Delete "${badge.name}"?'),
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
      await ApiService().deleteBadge(badge.id);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.event.title} Badges'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.surface, cs.surfaceContainerHighest.withValues(alpha: 0.85)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<Badge>>(
          future: _badgesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final badges = snapshot.data ?? [];

            if (badges.isEmpty) {
              return const Center(child: Text('No badges for this event yet.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: badges.length,
              itemBuilder: (context, index) {
                final badge = badges[index];
                return ListTile(
                  leading: const Icon(Icons.military_tech, size: 32),
                  title: Text(badge.name),
                  subtitle: Text(
                      '${badge.winningCondition?.metric.toUpperCase()} ${badge.winningCondition?.operator} ${badge.winningCondition?.value}'),
                  trailing: widget.event.status != 'closed'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editBadge(badge),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              onPressed: () => _deleteBadge(badge),
                            ),
                          ],
                        )
                      : null,
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: widget.event.status != 'closed'
          ? FloatingActionButton.extended(
              onPressed: _createBadge,
              icon: const Icon(Icons.add),
              label: const Text('New Badge'),
            )
          : null,
    );
  }
}
