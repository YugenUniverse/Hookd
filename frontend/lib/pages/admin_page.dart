import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/support_ticket.dart';
import '../utils/error_helpers.dart';
import 'support_page.dart' show SupportStatusChip, SupportCategoryChip;

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
  List<SupportTicket> _supportTickets = [];
  String? _ticketStatusFilter;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        ApiService().adminGetSupportTickets(status: _ticketStatusFilter),
      ]);
      if (mounted) {
        setState(() {
          _pendingApprovals = results[0] as List<User>;
          _flaggedReviews = results[1] as List<Map<String, dynamic>>;
          _supportTickets = results[2] as List<SupportTicket>;
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
                  const Text('Support'),
                  if (_supportTickets.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _CountBadge(_supportTickets.length),
                  ],
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
                _buildApprovalsList(),
                _buildFlaggedList(),
                _buildSupportList(),
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

  Widget _buildSupportList() {
    final cs = Theme.of(context).colorScheme;

    const statuses = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];

    if (_supportTickets.isEmpty) {
      return Column(
        children: [
          _buildTicketFilterBar(cs, statuses),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.support_agent_outlined, size: 56),
                  SizedBox(height: 12),
                  Text('No tickets', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildTicketFilterBar(cs, statuses),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _supportTickets.length,
            itemBuilder: (context, index) {
              final ticket = _supportTickets[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openTicketDialog(ticket),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(ticket.subject,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            const SizedBox(width: 8),
                            SupportStatusChip(status: ticket.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (ticket.user != null) ...[
                          Row(children: [
                            Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '@${ticket.user!['username'] ?? ticket.user!['email'] ?? ''}',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                          ]),
                          const SizedBox(height: 4),
                        ],
                        Text(ticket.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Row(children: [
                          SupportCategoryChip(category: ticket.category),
                          const Spacer(),
                          if (ticket.hasReply)
                            Row(children: [
                              Icon(Icons.reply, size: 14, color: cs.primary),
                              const SizedBox(width: 4),
                              Text('Replied',
                                  style: TextStyle(fontSize: 12, color: cs.primary)),
                            ]),
                        ]),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketFilterBar(ColorScheme cs, List<String> statuses) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _ticketStatusFilter == null,
            onSelected: (_) {
              setState(() => _ticketStatusFilter = null);
              _fetchData();
            },
          ),
          const SizedBox(width: 8),
          ...statuses.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s.replaceAll('_', ' ')),
                  selected: _ticketStatusFilter == s,
                  onSelected: (_) {
                    setState(() => _ticketStatusFilter = _ticketStatusFilter == s ? null : s);
                    _fetchData();
                  },
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _openTicketDialog(SupportTicket ticket) async {
    final refreshed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AdminTicketDialog(ticket: ticket),
    );
    if (refreshed == true) _fetchData();
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Admin ticket detail dialog
// ──────────────────────────────────────────────────────────────────────────────

class _AdminTicketDialog extends StatefulWidget {
  final SupportTicket ticket;

  const _AdminTicketDialog({required this.ticket});

  @override
  State<_AdminTicketDialog> createState() => _AdminTicketDialogState();
}

class _AdminTicketDialogState extends State<_AdminTicketDialog> {
  final _replyCtrl = TextEditingController();
  String _selectedStatus = 'IN_PROGRESS';
  bool _isSubmitting = false;

  static const _statuses = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];

  @override
  void initState() {
    super.initState();
    _replyCtrl.text = widget.ticket.adminReply ?? '';
    _selectedStatus = widget.ticket.status == 'OPEN' ? 'IN_PROGRESS' : widget.ticket.status;
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final reply = _replyCtrl.text.trim();
    if (reply.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await ApiService().adminReplyToTicket(
        widget.ticket.id,
        reply: reply,
        status: _selectedStatus,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showErrorDetailsDialog(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _updateStatusOnly(String status) async {
    setState(() => _isSubmitting = true);
    try {
      await ApiService().adminUpdateTicketStatus(widget.ticket.id, status);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showErrorDetailsDialog(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ticket = widget.ticket;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(ticket.subject, style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 8),
          SupportStatusChip(status: ticket.status),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ticket.user != null)
                Text(
                  '@${ticket.user!['username'] ?? ticket.user!['email'] ?? ''}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              const SizedBox(height: 4),
              SupportCategoryChip(category: ticket.category),
              const SizedBox(height: 12),
              Text(ticket.body, style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Set Status', isDense: true),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.replaceAll('_', ' ')),
                        ))
                    .toList(),
                onChanged: _isSubmitting ? null : (v) => setState(() => _selectedStatus = v ?? _selectedStatus),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _replyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reply to user',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 2000,
                enabled: !_isSubmitting,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => _updateStatusOnly(_selectedStatus),
          child: const Text('Status Only'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitReply,
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send Reply'),
        ),
      ],
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
