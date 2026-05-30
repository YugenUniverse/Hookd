import 'dart:async';
import 'package:flutter/material.dart';

import '../models/poi.dart';
import '../services/api_service.dart';

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key, this.groupId});

  final String? groupId;

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  
  // Venue Search
  final _searchController = TextEditingController();
  Poi? _selectedVenue;
  List<Poi> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  final Set<String> _selectedWalls = {};

  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearching = true);
      final results = await ApiService().searchPois(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectVenue(Poi poi) {
    setState(() {
      _selectedVenue = poi;
      _searchResults = [];
      _searchController.clear();
      _selectedWalls.clear();
    });
  }

  void _clearVenue() {
    setState(() {
      _selectedVenue = null;
      _searchResults = [];
      _selectedWalls.clear();
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a start date')),
      );
      return;
    }
    
    String? facilityId;
    List<String> eventWalls = [];
    
    if (_selectedVenue != null) {
       final venue = _selectedVenue!;
       if (venue is FacilityPoi) {
           facilityId = venue.id;
           eventWalls = _selectedWalls.toList();
       } else {
           eventWalls = [venue.id];
       }
    }

    setState(() => _submitting = true);
    try {
      final event = await ApiService().createEvent(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        startDate: _startDate!,
        endDate: _endDate,
        groupId: widget.groupId,
        facilityId: facilityId,
        walls: eventWalls,
      );
      if (!mounted) return;
      Navigator.of(context).pop(event);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create event: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title *'),
                maxLength: 100,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
                maxLength: 1000,
              ),
              const SizedBox(height: 16),
              _DatePickerTile(
                label: 'Start date *',
                value: _startDate,
                onTap: () => _pickDate(isStart: true),
                formatDate: _formatDate,
              ),
              const SizedBox(height: 12),
              _DatePickerTile(
                label: 'End date (optional)',
                value: _endDate,
                onTap: () => _pickDate(isStart: false),
                formatDate: _formatDate,
              ),
              const SizedBox(height: 24),
              
              Text(
                'Location (optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_selectedVenue != null) ...[
                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  elevation: 0,
                  child: ListTile(
                    leading: Icon(
                      _selectedVenue is FacilityPoi ? Icons.business : Icons.terrain,
                    ),
                    title: Text(_selectedVenue!.name),
                    subtitle: Text(
                      _selectedVenue is FacilityPoi ? 'Facility' : 'Outdoor Wall',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearVenue,
                    ),
                  ),
                ),
                if (_selectedVenue is FacilityPoi) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Select specific walls for this event (leave empty for whole facility):',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: (_selectedVenue as FacilityPoi).walls.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant),
                      itemBuilder: (context, index) {
                        final w = (_selectedVenue as FacilityPoi).walls[index];
                        final selected = _selectedWalls.contains(w.id);
                        return CheckboxListTile(
                          value: selected,
                          title: Text(w.name),
                          subtitle: Text('Grade: ${w.difficulty}'),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedWalls.add(w.id);
                              } else {
                                _selectedWalls.remove(w.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ] else ...[
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search facility or wall...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final poi = _searchResults[index];
                        return ListTile(
                          leading: Icon(
                            poi is FacilityPoi ? Icons.business : Icons.terrain,
                          ),
                          title: Text(poi.name),
                          subtitle: Text(poi.description, maxLines: 1),
                          onTap: () => _selectVenue(poi),
                        );
                      },
                    ),
                  ),
              ],
              
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
    required this.formatDate,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value != null ? formatDate(value!) : 'Tap to select',
          style: value != null
              ? null
              : TextStyle(color: Theme.of(context).hintColor),
        ),
      ),
    );
  }
}
