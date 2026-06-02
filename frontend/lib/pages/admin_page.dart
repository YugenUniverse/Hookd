import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/error_helpers.dart';
import '../widgets/admin_walls_tab.dart';
import '../widgets/admin_overview_tab.dart';


class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<User> _pendingApprovals = [];
  List<Map<String, dynamic>> _flaggedReviews = [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService().getPendingApprovals(),
        ApiService().getFlaggedReviews(),
      ]);
      if (mounted) {
        setState(() {
          _pendingApprovals = results[0] as List<User>;
          _flaggedReviews = results[1] as List<Map<String, dynamic>>;
        });
      }
    } catch (e) {
      if (mounted) showErrorDetailsDialog(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleApprove(User user) async {
    setState(() => _busy.add(user.id));
    try {
      await ApiService().approveAccount(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${user.username} approved')));
      _fetchData();
    } catch (e) {
      if (mounted) showErrorDetailsDialog(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(user.id));
    }
  }

  Future<void> _handleReject(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject account'),
        content: Text('Reject @${user.username}? They will be notified by email.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy.add(user.id));
    try {
      await ApiService().rejectAccount(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${user.username} rejected')));
      _fetchData();
    } catch (e) {
      if (mounted) showErrorDetailsDialog(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(user.id));
    }
  }

  Future<void> _handleRemove(Map<String, dynamic> review) async {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Review removed')));
      _fetchData();
    } catch (e) {
      if (mounted) showErrorDetailsDialog(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _handleDismiss(Map<String, dynamic> review) async {
    final id = (review['id'] ?? review['_id'] ?? '').toString();
    setState(() => _busy.add(id));
    try {
      await ApiService().adminDismissFlag(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Flag dismissed')));
      _fetchData();
    } catch (e) {
      if (mounted) showErrorDetailsDialog(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _fetchData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Overview'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Approvals'),
                  if (_pendingApprovals.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _CountBadge(_pendingApprovals.length),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Flagged'),
                  if (_flaggedReviews.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _CountBadge(_flaggedReviews.length, isError: true),
                  ],
                ],
              ),
            ),

            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Walls'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                const AdminOverviewTab(),
                _buildApprovalsList(),
                _buildFlaggedList(),
                const AdminWallsTab(),
              ],

            ),
    );
  }

  Widget _buildApprovalsList() {
    final cs = Theme.of(context).colorScheme;

    if (_pendingApprovals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 56),
            SizedBox(height: 12),
            Text('No pending requests', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _pendingApprovals.length,
      itemBuilder: (context, index) {
        final user = _pendingApprovals[index];
        final isBusy = _busy.contains(user.id);

        final typeLabel = user.userType == 'FacilityOwner' ? 'Gym Operator' : 'Public Body';
        final typeIcon = user.userType == 'FacilityOwner'
            ? Icons.fitness_center
            : Icons.account_balance;

        final displayName = user.name != null && user.surname != null
            ? '${user.name} ${user.surname}'
            : user.name ?? user.publicBodyData?.name ?? user.facilityData?.name;

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
                      backgroundColor: cs.primaryContainer,
                      child: Icon(typeIcon, size: 20, color: cs.onPrimaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@${user.username}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(user.email,
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(typeLabel, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: cs.secondaryContainer,
                      labelStyle: TextStyle(color: cs.onSecondaryContainer),
                    ),
                  ],
                ),
                if (displayName != null) ...[
                  const SizedBox(height: 8),
                  Text(displayName, style: const TextStyle(fontSize: 14)),
                ],
                if (user.facilityData?.name != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.business, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(user.facilityData!.name,
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ]),
                ],
                if (user.publicBodyData?.address != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(user.publicBodyData!.address!,
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(user.bio!,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 12),
                if (isBusy)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _handleReject(user),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _handleApprove(user),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlaggedList() {
    final cs = Theme.of(context).colorScheme;

    if (_flaggedReviews.isEmpty) {
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
      itemCount: _flaggedReviews.length,
      itemBuilder: (context, index) {
        final review = _flaggedReviews[index];
        final id = (review['id'] ?? review['_id'] ?? '').toString();
        final isBusy = _busy.contains(id);

        final session = review['climbing_session_id'];
        final climber = session is Map ? session['climber_id'] : null;
        final wall = session is Map ? session['wall_id'] : null;

        String extractField(dynamic obj, List<String> keys) {
          if (obj is! Map) return 'Unknown';
          for (final k in keys) {
            if (obj[k] != null) return obj[k].toString();
          }
          return 'Unknown';
        }

        final reviewerName = extractField(climber, ['username', 'email']);
        final reviewerEmail = climber is Map ? (climber['email']?.toString() ?? '') : '';
        final wallName = extractField(wall, ['name']);
        final body = (review['body'] ?? '').toString();
        final rating = (review['rating'] ?? 0) as num;
        final flagReason = (review['flagReason'] ?? '').toString();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (flagReason.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: cs.errorContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.flag, size: 15, color: cs.onErrorContainer),
                      const SizedBox(width: 8),
                      Text(
                        flagReason,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: cs.surfaceContainerHighest,
                      child: Text(
                        reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@$reviewerName',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          if (reviewerEmail.isNotEmpty)
                            Text(reviewerEmail,
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.terrain, size: 15, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(wallName,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 18,
                        color: i < rating ? Colors.amber.shade600 : cs.outlineVariant,
                      )),
                    ),
                  ],
                ),
              ),
              if (body.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Divider(height: 1),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface,
                          height: 1.5,
                        ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: isBusy
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _handleDismiss(review),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Dismiss'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _handleRemove(review),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Remove'),
                            style: FilledButton.styleFrom(backgroundColor: cs.error),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool isError;

  const _CountBadge(this.count, {this.isError = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isError ? cs.error : cs.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isError ? cs.onError : cs.onPrimary,
        ),
      ),
    );
  }
}
