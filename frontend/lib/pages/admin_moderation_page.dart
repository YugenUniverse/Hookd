import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ApiService().getFlaggedReviews();
    });
  }

  Future<void> _removeReview(Map<String, dynamic> review) async {
    final id = (review['id'] ?? review['_id'] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove review'),
        content: const Text('Remove this review? The author will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy.add(id));
    try {
      await ApiService().adminRemoveReview(id, reason: review['flagReason']?.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review removed')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _dismissFlag(Map<String, dynamic> review) async {
    final id = (review['id'] ?? review['_id'] ?? '').toString();
    setState(() => _busy.add(id));
    try {
      await ApiService().adminDismissFlag(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flag dismissed')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flagged Reviews'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _load),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  Text('Failed to load: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            );
          }
          final reviews = snapshot.data ?? [];
          if (reviews.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 56),
                  SizedBox(height: 12),
                  Text('No flagged reviews', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              final id = (review['id'] ?? review['_id'] ?? '').toString();
              final isBusy = _busy.contains(id);
              return _FlaggedReviewCard(
                review: review,
                isBusy: isBusy,
                cs: cs,
                onRemove: isBusy ? null : () => _removeReview(review),
                onDismiss: isBusy ? null : () => _dismissFlag(review),
              );
            },
          );
        },
      ),
    );
  }
}

class _FlaggedReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final bool isBusy;
  final ColorScheme cs;
  final VoidCallback? onRemove;
  final VoidCallback? onDismiss;

  const _FlaggedReviewCard({
    required this.review,
    required this.isBusy,
    required this.cs,
    required this.onRemove,
    required this.onDismiss,
  });

  String _extractField(dynamic obj, List<String> keys) {
    if (obj is! Map) return 'Unknown';
    for (final key in keys) {
      if (obj[key] != null) return obj[key].toString();
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final session = review['climbing_session_id'];
    final climber = session is Map ? session['climber_id'] : null;
    final wall = session is Map ? session['wall_id'] : null;

    final reviewerName = _extractField(climber, ['username', 'email']);
    final reviewerEmail = climber is Map ? (climber['email']?.toString() ?? '') : '';
    final wallName = _extractField(wall, ['name']);
    final body = (review['body'] ?? '').toString();
    final rating = (review['rating'] ?? 0) as num;
    final flagReason = (review['flagReason'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.errorContainer,
                  child: Icon(Icons.flag, size: 20, color: cs.onErrorContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@$reviewerName',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (reviewerEmail.isNotEmpty)
                        Text(
                          reviewerEmail,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                        ),
                    ],
                  ),
                ),
                if (flagReason.isNotEmpty)
                  Chip(
                    label: Text(flagReason, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: cs.errorContainer,
                    labelStyle: TextStyle(color: cs.onErrorContainer),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.terrain, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    wallName,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Text(
                  '$rating / 5',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            if (isBusy)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Dismiss'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    style: FilledButton.styleFrom(backgroundColor: cs.error),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
