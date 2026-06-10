import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/statistics_filter.dart';

class _Location {
  final String name;
  final double lat;
  final double lng;
  const _Location(this.name, this.lat, this.lng);
}

const _kLocations = [
  _Location('Trento', 46.0748, 11.1217),
  _Location('Rovereto', 45.8907, 11.0388),
  _Location('Riva del Garda', 45.8867, 10.8408),
  _Location('Arco', 45.9186, 10.8859),
  _Location('Bolzano', 46.4983, 11.3548),
  _Location('Merano', 46.6727, 11.1597),
  _Location('Bressanone', 46.7174, 11.6567),
  _Location('Pergine', 46.0645, 11.2353),
];

enum _TimePreset {
  today('Today', 0),
  week('7 days', 7),
  month('30 days', 30),
  quarter('3 months', 90),
  year('1 year', 365),
  custom('Custom', -1);

  const _TimePreset(this.label, this.days);
  final String label;
  final int days;
}

/// Computes a bounding box around [centerLat]/[centerLng] within [radiusKm].
Map<String, double> _computeBbox(double centerLat, double centerLng, double radiusKm) {
  const earthKm = 6371.0;
  final deltaLat = (radiusKm / earthKm) * (180 / pi);
  final deltaLng = (radiusKm / earthKm) * (180 / pi) / cos(centerLat * pi / 180);
  return {
    'minLat': centerLat - deltaLat,
    'maxLat': centerLat + deltaLat,
    'minLng': centerLng - deltaLng,
    'maxLng': centerLng + deltaLng,
  };
}

class StatisticsFilterWidget extends StatefulWidget {
  final Function(StatisticsFilter) onFilterChanged;
  final Function(StatisticsFilter)? onPreviewChanged;
  final StatisticsFilter? initialFilter;

  const StatisticsFilterWidget({
    super.key,
    required this.onFilterChanged,
    this.onPreviewChanged,
    this.initialFilter,
  });

  @override
  State<StatisticsFilterWidget> createState() => _StatisticsFilterWidgetState();
}

class _StatisticsFilterWidgetState extends State<StatisticsFilterWidget> {
  _Location? _selectedLocation = _kLocations.first;
  double _radiusKm = 30;
  bool _customCenter = false;

  final _customLatController = TextEditingController();
  final _customLngController = TextEditingController();

  _TimePreset _timePreset = _TimePreset.month;
  late DateTime _startDate;
  late DateTime _endDate;
  late final TextEditingController _dateRangeController;

  @override
  void initState() {
    super.initState();
    _endDate = widget.initialFilter?.endDate ?? DateTime.now();
    _startDate = widget.initialFilter?.startDate ??
        DateTime.now().subtract(const Duration(days: 30));
    _dateRangeController = TextEditingController(
      text: _formatRange(_startDate, _endDate),
    );
    _customLatController.addListener(_notifyPreview);
    _customLngController.addListener(_notifyPreview);
  }

  @override
  void dispose() {
    _customLatController.dispose();
    _customLngController.dispose();
    _dateRangeController.dispose();
    super.dispose();
  }

  void _notifyPreview() {
    if (widget.onPreviewChanged == null) return;
    double centerLat, centerLng;
    if (_customCenter) {
      final lat = double.tryParse(_customLatController.text.trim());
      final lng = double.tryParse(_customLngController.text.trim());
      if (lat == null || lng == null) return;
      centerLat = lat;
      centerLng = lng;
    } else {
      if (_selectedLocation == null) return;
      centerLat = _selectedLocation!.lat;
      centerLng = _selectedLocation!.lng;
    }
    final bbox = _computeBbox(centerLat, centerLng, _radiusKm);
    widget.onPreviewChanged!(StatisticsFilter(
      minLat: bbox['minLat']!,
      maxLat: bbox['maxLat']!,
      minLng: bbox['minLng']!,
      maxLng: bbox['maxLng']!,
      startDate: _startDate,
      endDate: _endDate,
    ));
  }

  String _formatRange(DateTime s, DateTime e) {
    final f = DateFormat('MMM d, yyyy');
    return '${f.format(s)} – ${f.format(e)}';
  }

  void _onTimePresetSelected(_TimePreset preset) {
    setState(() {
      _timePreset = preset;
      if (preset == _TimePreset.today) {
        final now = DateTime.now();
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = now;
      } else if (preset != _TimePreset.custom) {
        _endDate = DateTime.now();
        _startDate = _endDate.subtract(Duration(days: preset.days));
      }
      if (preset != _TimePreset.custom) {
        _dateRangeController.text = _formatRange(_startDate, _endDate);
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _dateRangeController.text = _formatRange(_startDate, _endDate);
      });
    }
  }

  StatisticsFilter? _buildFilter() {
    double centerLat, centerLng;

    if (_customCenter) {
      final lat = double.tryParse(_customLatController.text.trim());
      final lng = double.tryParse(_customLngController.text.trim());
      if (lat == null || lng == null) {
        _showError('Enter valid latitude and longitude');
        return null;
      }
      centerLat = lat;
      centerLng = lng;
    } else {
      if (_selectedLocation == null) {
        _showError('Select a location');
        return null;
      }
      centerLat = _selectedLocation!.lat;
      centerLng = _selectedLocation!.lng;
    }

    if (!_startDate.isBefore(_endDate)) {
      _showError('Start date must be before end date');
      return null;
    }

    final bbox = _computeBbox(centerLat, centerLng, _radiusKm);
    return StatisticsFilter(
      minLat: bbox['minLat']!,
      maxLat: bbox['maxLat']!,
      minLng: bbox['minLng']!,
      maxLng: bbox['maxLng']!,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _reset() {
    setState(() {
      _selectedLocation = _kLocations.first;
      _customCenter = false;
      _radiusKm = 30;
      _customLatController.clear();
      _customLngController.clear();
      _timePreset = _TimePreset.month;
      _endDate = DateTime.now();
      _startDate = _endDate.subtract(const Duration(days: 30));
      _dateRangeController.text = _formatRange(_startDate, _endDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Area ──────────────────────────────────────
          _sectionLabel(context, Icons.place_outlined, 'Area'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ..._kLocations.map((loc) => FilterChip(
                    label: Text(loc.name),
                    selected: !_customCenter && _selectedLocation == loc,
                    onSelected: (_) {
                      setState(() {
                        _customCenter = false;
                        _selectedLocation = loc;
                      });
                      _notifyPreview();
                    },
                    visualDensity: VisualDensity.compact,
                  )),
              FilterChip(
                label: const Text('Custom'),
                selected: _customCenter,
                onSelected: (_) => setState(() {
                  _customCenter = true;
                  _selectedLocation = null;
                }),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (_customCenter) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _customLatController,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'e.g. 46.07',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _customLngController,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'e.g. 11.12',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.radar, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Radius: ${_radiusKm.round()} km',
                style: theme.textTheme.labelMedium,
              ),
              Expanded(
                child: Slider(
                  value: _radiusKm,
                  min: 5,
                  max: 200,
                  divisions: 39,
                  label: '${_radiusKm.round()} km',
                  onChanged: (v) {
                    setState(() => _radiusKm = v);
                    _notifyPreview();
                  },
                ),
              ),
            ],
          ),

          Divider(height: 24, color: cs.outlineVariant.withValues(alpha: 0.4)),

          // ── Period ────────────────────────────────────
          _sectionLabel(context, Icons.schedule_outlined, 'Period'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _TimePreset.values
                .map((p) => FilterChip(
                      label: Text(p.label),
                      selected: _timePreset == p,
                      onSelected: (_) => _onTimePresetSelected(p),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          if (_timePreset == _TimePreset.custom)
            TextField(
              controller: _dateRangeController,
              decoration: const InputDecoration(
                labelText: 'Date range',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
                isDense: true,
              ),
              readOnly: true,
              onTap: _pickCustomRange,
            )
          else
            Text(
              _formatRange(_startDate, _endDate),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),

          const SizedBox(height: 16),

          // ── Actions ───────────────────────────────────
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: () {
                  final f = _buildFilter();
                  if (f != null) widget.onFilterChanged(f);
                },
                child: const Text('Apply'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _reset,
              child: const Text('Reset'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(text,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
