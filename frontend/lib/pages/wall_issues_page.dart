import 'package:flutter/material.dart';

import '../models/issue.dart';
import '../services/api_service.dart';

const _statuses = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];

class WallIssuesPage extends StatefulWidget {
  const WallIssuesPage({super.key});

  @override
  State<WallIssuesPage> createState() => _WallIssuesPageState();
}

class _WallIssuesPageState extends State<WallIssuesPage> {
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

  Future<void> _updateStatus(Issue issue, String newStatus) async {
    try {
      await ApiService().updateIssueStatus(issue.id!, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to ${_statusLabel(newStatus)}')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Wall issues')),
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
                      Text('Unable to load issues', style: theme.textTheme.titleLarge),
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
                        'No issues reported',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your walls have no open issues.',
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
                  return _WallIssueCard(
                    issue: issue,
                    onStatusChange: (newStatus) => _updateStatus(issue, newStatus),
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

class _WallIssueCard extends StatelessWidget {
  const _WallIssueCard({required this.issue, required this.onStatusChange});

  final Issue issue;
  final void Function(String newStatus) onStatusChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (statusColor, statusLabel) = _statusInfo(issue.status, colorScheme);
    final dateLabel = issue.submittedAt != null ? _formatDate(issue.submittedAt!) : 'Unknown date';
    final nextStatuses = _statuses.where((s) => s != issue.status.toUpperCase()).toList();

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
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: nextStatuses.map((s) {
              final (color, label) = _statusInfo(s, colorScheme);
              return OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                onPressed: () => onStatusChange(s),
                child: Text('Mark as $label'),
              );
            }).toList(),
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

String _statusLabel(String status) {
  return switch (status.toUpperCase()) {
    'OPEN' => 'Open',
    'IN_PROGRESS' => 'In progress',
    'RESOLVED' => 'Resolved',
    'CLOSED' => 'Closed',
    _ => status,
  };
}
