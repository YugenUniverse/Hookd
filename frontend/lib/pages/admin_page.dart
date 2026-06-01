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
  bool _approvalsExpanded = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final approvals = await ApiService().getPendingApprovals();
      if (mounted) {
        setState(() {
          _pendingApprovals = approvals;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleApprove(String userId) async {
    try {
      await ApiService().approveAccount(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account approved successfully')),
        );
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, e);
      }
    }
  }

  Future<void> _handleReject(String userId) async {
    try {
      await ApiService().rejectAccount(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account rejected')),
        );
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, e);
      }
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
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExpansionPanelList(
                    elevation: 1,
                    expandedHeaderPadding: EdgeInsets.zero,
                    expansionCallback: (int index, bool isExpanded) {
                      setState(() {
                        _approvalsExpanded = isExpanded;
                      });
                    },
                    children: [
                      ExpansionPanel(
                        headerBuilder: (BuildContext context, bool isExpanded) {
                          return ListTile(
                            leading: const Icon(Icons.verified_user_outlined),
                            title: const Text(
                              'Pending Approvals',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${_pendingApprovals.length} requests'),
                          );
                        },
                        body: _buildPendingApprovalsList(),
                        isExpanded: _approvalsExpanded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPendingApprovalsList() {
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
                    label: Text(
                      type,
                      style: const TextStyle(fontSize: 12),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                details,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _handleReject(user.id),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reject', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _handleApprove(user.id),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
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
