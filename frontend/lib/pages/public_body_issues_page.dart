import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../widgets/critical_issues_panel.dart';

class PublicBodyIssuesPage extends StatefulWidget {
  final void Function(String wallId, String wallName, double lat, double lng)? onWallTapped;

  const PublicBodyIssuesPage({super.key, this.onWallTapped});

  @override
  State<PublicBodyIssuesPage> createState() => _PublicBodyIssuesPageState();
}

class _PublicBodyIssuesPageState extends State<PublicBodyIssuesPage> {
  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Critical Issues'),
        centerTitle: true,
      ),
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
        child: SafeArea(
          child: CriticalIssuesPanel(
            onRefresh: _refresh,
            onWallTapped: widget.onWallTapped,
          ),
        ),
      ),
    );
  }
}
