import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/error_helpers.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _isLoading = true;
  List<User> _pendingApprovals = [];
  List<Map<String, dynamic>> _flaggedReviews = [];
  bool _approvalsExpanded = true;
  bool _moderationExpanded = true;
  final Set<String> _busyReviews = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
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

  Future<void> _handleApprove(String userId) async {
    try {
      await ApiService().approveAccount(userId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Account approved successfully')));
      }
      _fetchData();
    } catch (e) {
      if (mounted) showErrorDetailsDialog(context, e);
    }
  }

  Future<void> _handleReject(String userId) async {
    try {
      await ApiService().rejectAccount(userId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Account rejected')));
      }
      _fetchData();
    } catch (e) {
      if (mounted) showErrorDetailsDialog(context, e);
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

    setState(() => _busyReviews.add(id));
    try {
      await ApiService().adminRemoveReview(id, reason: review['flagReason']?.toString());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Review removed')));
      }
      _fetchData();
    } catch (e) {
      if (mounted) showErrorDetailsDialog(context, e);
    } finally {
      if (mounted) setState(() => _busyReviews.remove(id));
    }
  }

  Future<void> _handleDismiss(Map<String, dynamic> review) async {
    final id = (review['id'] ?? review['_id'] ?? '').toString();
    setState(() => _busyReviews.add(id));
    try {
      await ApiService().adminDismissFlag(id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Flag dismissed')));
      }
      _fetchData();
    } catch (e) {
      if (mounted) showErrorDetailsDialog(context, e);
    } finally {
      if (mounted) setState(() => _busyReviews.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ExpansionPanelList(
                elevation: 1,
                expandedHeaderPadding: EdgeInsets.zero,
                expansionCallback: (index, isExpanded) {
                  setState(() {
                    if (index == 0) _approvalsExpanded = isExpanded;
                    if (index == 1) _moderationExpanded = isExpanded;
                  });
                },
                children: [
                  ExpansionPanel(
                    isExpanded: _approvalsExpanded,
                    headerBuilder: (context, isExpanded) => ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text(
                        'Pending Approvals',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${_pendingApprovals.length} requests'),
                    ),
                    body: _buildApprovalsList(),
                  ),
                  ExpansionPanel(
                    isExpanded: _moderationExpanded,
                    headerBuilder: (context, isExpanded) => ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text(
                        'Flagged Reviews',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${_flaggedReviews.length} flagged'),
                    ),
                    body: _buildFlaggedList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildApprovalsList() {
    if (_pendingApprovals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No pending approvals at this time.'),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pendingApprovals.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _pendingApprovals[index];
        final name = user.username.isNotEmpty ? user.username : 'Unknown User';
        final type = user.userType ?? 'Unknown Type';

        String details = 'Email: ${user.email}';
        if (user.userType == 'FacilityOwner' && user.facilityData != null) {
          details += '\nFacility: ${user.facilityData!.name}';
        } else if (user.userType == 'PublicBody' && user.publicBodyData != null) {
          details += '\nPublic Body: ${user.publicBodyData!.name}';
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Chip(
                    label: Text(type, style: const TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(details, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _handleReject(user.id),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reject', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _handleApprove(user.id),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlaggedList() {
    if (_flaggedReviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No flagged reviews.'),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _flaggedReviews.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final review = _flaggedReviews[index];
        final id = (review['id'] ?? review['_id'] ?? '').toString();
        final isBusy = _busyReviews.contains(id);

        final session = review['climbing_session_id'];
        final climber = session is Map ? session['climber_id'] : null;
        final wall = session is Map ? session['wall_id'] : null;

        String extractField(dynamic obj, List<String> keys) {
          if (obj is! Map) return 'Unknown';
          for (final key in keys) {
            if (obj[key] != null) return obj[key].toString();
          }
          return 'Unknown';
        }

        final reviewerName = extractField(climber, ['username', 'email']);
        final reviewerEmail = climber is Map ? (climber['email']?.toString() ?? '') : '';
        final wallName = extractField(wall, ['name']);
        final body = (review['body'] ?? '').toString();
        final rating = (review['rating'] ?? 0) as num;
        final flagReason = (review['flagReason'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.errorContainer,
                    child: Icon(Icons.flag, size: 16, color: cs.onErrorContainer),
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
                    child: Text(wallName,
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                  const SizedBox(width: 4),
                  Text('$rating / 5', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(body,
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
            ],
          ),
        );
      },
    );
  }
}
