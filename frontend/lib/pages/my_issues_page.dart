import 'package:flutter/material.dart';

import '../models/issue.dart';
import '../services/api_service.dart';

class MyIssuesPage extends StatefulWidget {
  const MyIssuesPage({super.key});

  @override
  State<MyIssuesPage> createState() => _MyIssuesPageState();
}

class _MyIssuesPageState extends State<MyIssuesPage> {
  late Future<List<Issue>> _issuesFuture;

  @override
  void initState() {
    super.initState();
    _issuesFuture = ApiService().fetchIssuesForUser();
  }

  void _refresh() {
    setState(() {
      _issuesFuture = ApiService().fetchIssuesForUser();
    });
  }

  Future<void> _deleteIssue(Issue issue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete report?'),
        content: const Text('This will permanently remove your report. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService().deleteIssue(issue.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report deleted')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My reports')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<Issue>>(
          future: _issuesFuture,
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
                      Icon(Icons.error_outline, size: 44, color: colorScheme.error),
                      const SizedBox(height: 12),
                      Text('Unable to load reports', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
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

            final issues = snapshot.data ?? [];

            if (issues.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 56, color: colorScheme.primary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No reports submitted',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You haven\'t reported any issues yet.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: issues.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final issue = issues[index];
                  return _IssueCard(
                    issue: issue,
                    onDelete: () => _deleteIssue(issue),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue, required this.onDelete});

  final Issue issue;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (statusColor, statusLabel) = _statusInfo(issue.status, colorScheme);
    final dateLabel = issue.submittedAt != null ? _formatDate(issue.submittedAt!) : 'Unknown date';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wall: ${issue.wall_id}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            issue.body,
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete report'),
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _statusInfo(String status, ColorScheme cs) {
    return switch (status.toUpperCase()) {
      'OPEN' => (cs.primary, 'Open'),
      'IN_PROGRESS' => (Colors.orange, 'In progress'),
      'RESOLVED' => (Colors.green, 'Resolved'),
      'CLOSED' => (cs.outline, 'Closed'),
      _ => (cs.outline, status),
    };
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
