import 'package:flutter/material.dart';

import '../models/issue.dart';
import '../services/api_service.dart';

class CriticalIssuesPanel extends StatefulWidget {
  final VoidCallback? onRefresh;
  final void Function(String wallId, String wallName, double lat, double lng)? onWallTapped;

  const CriticalIssuesPanel({
    super.key,
    this.onRefresh,
    this.onWallTapped,
  });

  @override
  State<CriticalIssuesPanel> createState() => _CriticalIssuesPanelState();
}

class _CriticalIssuesPanelState extends State<CriticalIssuesPanel> {
  late Future<List<Issue>> _issuesFuture;
  late Future<Map<String, dynamic>> _summaryFuture;
  String? selectedStatus;
  String? selectedSeverity;

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  void _loadIssues() {
    final statuses = selectedStatus != null ? [selectedStatus!] : null;
    final severities = selectedSeverity != null ? [selectedSeverity!] : null;
    setState(() {
      _issuesFuture = ApiService()
          .fetchPublicBodyIssuesDashboard(statuses: statuses, severities: severities);
      _summaryFuture = ApiService().fetchPublicBodyIssueSummary();
    });
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'HIGH':
        return '🔴 High';
      case 'MEDIUM':
        return '🟠 Medium';
      case 'LOW':
        return '🟡 Low';
      default:
        return 'Unknown';
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'RESOLVED':
        return Colors.green;
      case 'CLOSED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateIssueStatus(Issue issue, String newStatus) async {
    try {
      await ApiService().updateIssueStatus(issue.id!, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus')),
      );
      _loadIssues();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards
        FutureBuilder<Map<String, dynamic>>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final data = snapshot.data ?? {};
            final totalOpen = data['totalOpen'] ?? 0;
            final highSeverity = data['highSeverity'] ?? 0;
            final mediumSeverity = data['mediumSeverity'] ?? 0;

            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Open',
                      count: totalOpen.toString(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryCard(
                      title: 'High',
                      count: highSeverity.toString(),
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Medium',
                      count: mediumSeverity.toString(),
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String?>(
                  value: selectedStatus,
                  isExpanded: true,
                  hint: const Text('Filter by status'),
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value;
                    });
                    _loadIssues();
                  },
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    ...['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String?>(
                  value: selectedSeverity,
                  isExpanded: true,
                  hint: const Text('Filter by severity'),
                  onChanged: (value) {
                    setState(() {
                      selectedSeverity = value;
                    });
                    _loadIssues();
                  },
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All severities'),
                    ),
                    ...['HIGH', 'MEDIUM', 'LOW'].map(
                      (severity) => DropdownMenuItem(
                        value: severity,
                        child: Text(severity),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Issues List
        Expanded(
          child: FutureBuilder<List<Issue>>(
            future: _issuesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              final issues = snapshot.data ?? [];

              if (issues.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No issues found',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  _loadIssues();
                  await Future.wait([_summaryFuture, _issuesFuture]);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: issues.length,
                  itemBuilder: (context, index) {
                    final issue = issues[index];
                    return _IssueCard(
                      issue: issue,
                      onStatusChanged: (newStatus) =>
                          _updateIssueStatus(issue, newStatus),
                      severityLabel: _severityLabel(issue.severity),
                      severityColor: _severityColor(issue.severity),
                      statusColor: _statusColor(issue.status),
                      onWallTapped: widget.onWallTapped,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String count;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final Issue issue;
  final Function(String) onStatusChanged;
  final String severityLabel;
  final Color severityColor;
  final Color statusColor;
  final void Function(String wallId, String wallName, double lat, double lng)? onWallTapped;

  const _IssueCard({
    required this.issue,
    required this.onStatusChanged,
    required this.severityLabel,
    required this.severityColor,
    required this.statusColor,
    this.onWallTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dateStr = issue.submittedAt != null
        ? MaterialLocalizations.of(context).formatShortDate(issue.submittedAt!)
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Severity, Wall, Location
            Row(
              children: [
                Chip(
                  label: Text(severityLabel),
                  backgroundColor: severityColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: severityColor),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: (onWallTapped != null &&
                            issue.wallLatitude != null &&
                            issue.wallLongitude != null)
                        ? () => onWallTapped!(
                              issue.wall_id,
                              issue.wallName ?? 'Wall',
                              issue.wallLatitude!,
                              issue.wallLongitude!,
                            )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              issue.wallName ?? 'Unknown wall',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: (onWallTapped != null &&
                                        issue.wallLatitude != null)
                                    ? TextDecoration.underline
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (onWallTapped != null && issue.wallLatitude != null) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.map_outlined,
                                  size: 12,
                                  color: theme.colorScheme.primary),
                            ],
                          ],
                        ),
                        if (issue.location.isNotEmpty)
                          Text(
                            issue.location,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Issue body
            Text(
              issue.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Description preview
            if (issue.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                issue.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 8),

            // Reporter and date
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Reporter: ${issue.displayClimberName} • $dateStr',
                    style: theme.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Status chip — tap to change status
            PopupMenuButton<String>(
              tooltip: 'Update status',
              onSelected: onStatusChanged,
              itemBuilder: (BuildContext context) => [
                'OPEN',
                'IN_PROGRESS',
                'RESOLVED',
                'CLOSED',
              ]
                  .where((s) => s != issue.status)
                  .map((String status) => PopupMenuItem<String>(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              child: Chip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      issue.status,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
                  ],
                ),
                backgroundColor: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
