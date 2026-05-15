import 'dart:async';

import 'package:flutter/material.dart';
import '../constants/api_config.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class ProfileDialog extends StatefulWidget {
  const ProfileDialog({super.key});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  Map<String, dynamic>? _serverStatus;
  bool _loadingStatus = true;

  // Facility claim
  final _facilitySearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _facilityResults = [];
  Map<String, dynamic>? _selectedFacility;
  Timer? _searchDebounce;
  bool _searching = false;
  bool _claiming = false;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    _facilitySearchCtrl.addListener(_onFacilitySearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _loadingStatus = true);
      _checkServerStatus();
    });
  }

  @override
  void dispose() {
    _facilitySearchCtrl.removeListener(_onFacilitySearchChanged);
    _facilitySearchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onFacilitySearchChanged() {
    final q = _facilitySearchCtrl.text.trim();
    _searchDebounce?.cancel();
    if (q.length < 2) {
      setState(() {
        _facilityResults = [];
        _selectedFacility = null;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await ApiService().searchFacilities(q);
      if (!mounted) return;
      setState(() {
        _facilityResults = results;
        _searching = false;
        if (_selectedFacility != null &&
            !results.any((r) => r['_id'] == _selectedFacility!['_id'])) {
          _selectedFacility = null;
        }
      });
    });
  }

  Future<void> _claimFacility() async {
    if (_selectedFacility == null) return;
    final facilityId = (_selectedFacility!['_id'] ?? _selectedFacility!['id'])?.toString();
    if (facilityId == null) return;

    setState(() => _claiming = true);
    final ok = await ApiService().claimFacility(facilityId);
    if (!mounted) return;
    setState(() {
      _claiming = false;
      if (ok) {
        _claimed = true;
        _facilityResults = [];
        _selectedFacility = null;
        _facilitySearchCtrl.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Facility claimed successfully!' : 'Failed to claim facility'),
    ));
  }

  void _showServerInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dns, size: 20),
            SizedBox(width: 8),
            Text('Server Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('URL', ApiConfig.apiBaseUrl),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Status',
              _serverStatus?['message'] ?? 'Unknown',
              statusColor: _serverStatus != null && _serverStatus!['status'] == 'online'
                  ? Colors.green
                  : null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? statusColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            if (statusColor != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, size: 16, color: statusColor),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _checkServerStatus() async {
    final status = await ApiService().checkServerHealth();
    if (mounted) {
      setState(() {
        _serverStatus = status;
        _loadingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = AuthService().username ?? 'User';
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final isFacilityOwner = AuthService().userType == 'FacilityOwner';

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 360,
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  child: Text(firstLetter),
                ),
                const SizedBox(height: 12),
                Text(username, style: theme.textTheme.headlineSmall),
                if (isFacilityOwner) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Gym / Facility',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (isFacilityOwner) ...[
                  const SizedBox(height: 16),
                  _buildClaimSection(theme),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.of(context).pop();
                        await AuthService().logout();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Logged out')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: _loadingStatus
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    : _buildStatusIcon(context),
                onPressed: _loadingStatus ? null : _showServerInfoDialog,
                tooltip: 'Server Info',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimSection(ThemeData theme) {
    if (_claimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Facility claimed!',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Claim your facility',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _facilitySearchCtrl,
          enabled: !_claiming,
          decoration: InputDecoration(
            labelText: 'Search by name',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _facilitySearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _facilitySearchCtrl.clear();
                          setState(() {
                            _facilityResults = [];
                            _selectedFacility = null;
                          });
                        },
                      )
                    : null,
          ),
        ),

        if (_selectedFacility != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.domain, size: 18, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFacility!['name']?.toString() ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _claiming
                      ? null
                      : () => setState(() => _selectedFacility = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _claiming ? null : _claimFacility,
            child: _claiming
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Claim facility'),
          ),
        ],

        if (_facilityResults.isNotEmpty && _selectedFacility == null) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _facilityResults.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.domain),
                    title: Text(_facilityResults[i]['name']?.toString() ?? ''),
                    subtitle: _facilityResults[i]['location']?['address'] != null
                        ? Text(_facilityResults[i]['location']['address'].toString())
                        : null,
                    onTap: () => setState(() {
                      _selectedFacility = _facilityResults[i];
                      _facilityResults = [];
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],

        if (_facilityResults.isEmpty &&
            _facilitySearchCtrl.text.trim().length >= 2 &&
            !_searching &&
            _selectedFacility == null) ...[
          const SizedBox(height: 8),
          Text(
            'No unclaimed facilities found. Contact us to add yours.',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    final serverHealthy =
        _serverStatus != null && _serverStatus!['status'] == 'online';

    return Stack(
      alignment: Alignment.center,
      children: [
        const Icon(Icons.dns, size: 20, color: Colors.white),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: serverHealthy ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(2),
            child: Icon(
              serverHealthy ? Icons.check : Icons.close,
              size: 10,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
