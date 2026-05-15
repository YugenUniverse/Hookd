import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wall.dart';
import '../services/api_service.dart';
import '../services/wall_service.dart';

class LogSessionPage extends StatefulWidget {
  const LogSessionPage({super.key, this.initialWall});

  final Wall? initialWall;

  @override
  State<LogSessionPage> createState() => _LogSessionPageState();
}

class _LogSessionPageState extends State<LogSessionPage> {
  final WallService _wallService = WallService();
  final ApiService _apiService = ApiService();

  final TextEditingController _wallQueryController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  List<Wall> _searchResults = [];
  Wall? _selectedWall;
  DateTime _selectedDate = DateTime.now();
  int? _selectedRating;
  bool _isPrivate = false;
  bool _loadingWalls = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final initialWall = widget.initialWall;
    if (initialWall != null) {
      _selectedWall = initialWall;
      _wallQueryController.text = initialWall.name;
    }
    _loadPrivacyPreference();
  }

  Future<void> _loadPrivacyPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPrivate = prefs.getBool('log_session_is_private') ?? false;
      if (mounted) {
        setState(() {
          _isPrivate = isPrivate;
        });
      }
    } catch (_) {
      // Silently fail, use default value
    }
  }

  Future<void> _savePrivacyPreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('log_session_is_private', value);
    } catch (_) {
      // Silently fail
    }
  }

  @override
  void dispose() {
    _wallQueryController.dispose();
    _timeController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _searchWalls() async {
    final query = _wallQueryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _loadingWalls = true;
    });

    try {
      final results = await _wallService.searchWalls(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to search walls right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingWalls = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final initial = _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedWall == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a wall first.')));
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final time = int.parse(_timeController.text.trim());

    setState(() {
      _submitting = true;
    });

    try {
      await _apiService.createSession(
        wallId: _selectedWall!.id,
        date: _selectedDate,
        time: time,
        rating: _selectedRating,
        reviewBody: _reviewController.text,
        isPrivate: _isPrivate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session logged successfully.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to log session: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String get _formattedDate {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: [
              Text(
                'Log climbing session',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text('Wall', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _wallQueryController,
                textInputAction: TextInputAction.search,
                enabled: _selectedWall == null,
                decoration: InputDecoration(
                  hintText: 'Search wall by name',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Search',
                    onPressed: _loadingWalls ? null : _searchWalls,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) =>
                    _selectedWall == null ? _searchWalls() : null,
              ),
              const SizedBox(height: 8),
              if (_selectedWall != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(_selectedWall!.name),
                    subtitle: Text('Selected wall'),
                    trailing: IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _selectedWall = null;
                        });
                      },
                    ),
                  ),
                ),
              if (_loadingWalls)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_searchResults.isNotEmpty)
                Card(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final wall = _searchResults[index];
                        return ListTile(
                          title: Text(wall.name),
                          subtitle: Text(wall.difficulty),
                          onTap: () {
                            setState(() {
                              _selectedWall = wall;
                              _searchResults = [];
                              _wallQueryController.text = wall.name;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Date', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_formattedDate),
                onPressed: _pickDate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Time (minutes)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final raw = value?.trim() ?? '';
                  if (raw.isEmpty) return 'Enter session time';
                  final parsed = int.tryParse(raw);
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid number of minutes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedRating,
                decoration: const InputDecoration(
                  labelText: 'Rating (optional)',
                  border: OutlineInputBorder(),
                ),
                items: const [1, 2, 3, 4, 5]
                    .map(
                      (rating) => DropdownMenuItem<int>(
                        value: rating,
                        child: Text('$rating / 5'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRating = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reviewController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Review notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isPrivate,
                activeColor: Theme.of(context).colorScheme.primary,
                title: const Text('Keep session private'),
                subtitle: const Text(
                  'Only you will see the rating and review text. The session still counts toward the wall totals.',
                ),
                onChanged: _submitting
                    ? null
                    : (value) {
                        setState(() {
                          _isPrivate = value;
                        });
                        _savePrivacyPreference(value);
                      },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Log session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
