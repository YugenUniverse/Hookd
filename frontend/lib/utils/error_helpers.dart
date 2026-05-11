import 'package:flutter/material.dart';

String errorSummary(Object? error) {
  final s = (error?.toString() ?? '').toLowerCase();
  if (s.contains('dioexception') ||
      s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('connection') ||
      s.contains('connection refused') ||
      s.contains('network')) {
    return 'Cannot reach server';
  }
  return 'An error occurred';
}

void showErrorDetailsDialog(BuildContext context, Object? error) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(errorSummary(error)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: SelectableText(error?.toString() ?? 'No additional details'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
      ],
    ),
  );
}

Widget buildFriendlyErrorCard(
  BuildContext context,
  Object? error, {
  VoidCallback? onRetry,
}) {
  final theme = Theme.of(context);
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 56, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            errorSummary(error),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'There was a problem contacting the server.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: onRetry ?? () => Navigator.of(context).maybePop(),
                child: const Text('Retry'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => showErrorDetailsDialog(context, error),
                child: const Text('Details'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class KeyringLockedException implements Exception {
  final String? message;
  KeyringLockedException([this.message]);
  @override
  String toString() => 'KeyringLockedException: ${message ?? 'Keyring locked'}';
}

void showKeyringLockedDialog(
  BuildContext context, {
  String? message,
  VoidCallback? onRetry,
  VoidCallback? onRelogin,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Keyring locked'),
      content: Text(message ??
          'The system keyring is locked. Please unlock it (e.g. GNOME keyring) or re-login.'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            if (onRelogin != null) onRelogin();
          },
          child: const Text('Re-login'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            if (onRetry != null) onRetry();
          },
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}