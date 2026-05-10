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

  @override
  void initState() {
    super.initState();
    // Defer server status check until after the dialog is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _loadingStatus = true);
      }
      _checkServerStatus();
    });
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

  Widget _buildDetailRow(String label, String value, {Color? statusColor, IconData? warningIcon}) {
    final showIcon = statusColor != null && warningIcon == null;
    final showWarning = warningIcon != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
            if (showIcon) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                size: 16,
                color: statusColor,
              ),
            ],
            if (showWarning) ...[
              const SizedBox(width: 8),
              Icon(
                warningIcon,
                size: 16,
                color: Colors.orange,
              ),
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
                Text(
                  username,
                  style: theme.textTheme.headlineSmall,
                ),
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
                            theme.colorScheme.onSurface.withOpacity(0.6),
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

  Widget _buildStatusIcon(BuildContext context) {
    final serverHealthy =
        _serverStatus != null && _serverStatus!['status'] == 'online';

    Color overlayColor = Colors.green;
    IconData overlayIcon = Icons.check;

    if (!serverHealthy) {
      overlayColor = Colors.red;
      overlayIcon = Icons.close;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.dns,
          size: 20,
          color: Colors.white,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: overlayColor,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(2),
            child: Icon(
              overlayIcon,
              size: 10,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
