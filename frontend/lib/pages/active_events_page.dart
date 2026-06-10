import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import 'event_detail_page.dart';

class ActiveEventsPage extends StatefulWidget {
  const ActiveEventsPage({super.key});

  @override
  State<ActiveEventsPage> createState() => _ActiveEventsPageState();
}

class _ActiveEventsPageState extends State<ActiveEventsPage> {
  bool _loading = true;
  String? _error;
  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await ApiService().getActiveEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      content = Center(
        child: Text('Failed to load events: $_error', style: TextStyle(color: cs.error)),
      );
    } else if (_events.isEmpty) {
      content = const Center(child: Text('No active events right now.'));
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];
          final dateLabel = event.endDate != null
              ? '${_formatDate(event.startDate)} – ${_formatDate(event.endDate!)}'
              : _formatDate(event.startDate);

          final isGlobal = event.isGlobal;
          final avatarColor = isGlobal ? Colors.amber.shade700 : cs.primary;
          final icon = isGlobal ? Icons.public : Icons.event;
          final subtitleText = isGlobal
              ? 'Global Challenge • $dateLabel'
              : dateLabel;

          return Card(
            elevation: isGlobal ? 4 : 0,
            color: isGlobal ? cs.primaryContainer : cs.surfaceContainerHighest,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isGlobal ? BorderSide(color: Colors.amber.shade700, width: 2) : BorderSide.none,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: avatarColor,
                child: Icon(icon, color: Colors.white),
              ),
              title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(subtitleText),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EventDetailPage(event: event)),
                );
              },
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Events'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.surface, cs.surfaceContainerHighest.withValues(alpha: 0.85)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: content,
      ),
    );
  }
}
