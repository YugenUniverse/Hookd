import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/statistics_filter.dart';

class StatisticsFilterWidget extends StatefulWidget {
  final Function(StatisticsFilter) onFilterChanged;
  final StatisticsFilter? initialFilter;

  const StatisticsFilterWidget({
    super.key,
    required this.onFilterChanged,
    this.initialFilter,
  });

  @override
  State<StatisticsFilterWidget> createState() => _StatisticsFilterWidgetState();
}

class _StatisticsFilterWidgetState extends State<StatisticsFilterWidget> {
  late DateTime _startDate;
  late DateTime _endDate;

  late TextEditingController _minLatController;
  late TextEditingController _maxLatController;
  late TextEditingController _minLngController;
  late TextEditingController _maxLngController;
  late TextEditingController _dateRangeController;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialFilter?.startDate ??
        DateTime.now().subtract(const Duration(days: 30));
    _endDate = widget.initialFilter?.endDate ?? DateTime.now();

    _minLatController = TextEditingController(
      text: widget.initialFilter != null
          ? widget.initialFilter!.minLat.toString()
          : '',
    );
    _maxLatController = TextEditingController(
      text: widget.initialFilter != null
          ? widget.initialFilter!.maxLat.toString()
          : '',
    );
    _minLngController = TextEditingController(
      text: widget.initialFilter != null
          ? widget.initialFilter!.minLng.toString()
          : '',
    );
    _maxLngController = TextEditingController(
      text: widget.initialFilter != null
          ? widget.initialFilter!.maxLng.toString()
          : '',
    );
    _dateRangeController = TextEditingController(
      text:
          '${DateFormat('yyyy-MM-dd').format(_startDate)} – ${DateFormat('yyyy-MM-dd').format(_endDate)}',
    );
  }

  @override
  void dispose() {
    _minLatController.dispose();
    _maxLatController.dispose();
    _minLngController.dispose();
    _maxLngController.dispose();
    _dateRangeController.dispose();
    super.dispose();
  }

  double? _parseCoord(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  StatisticsFilter? _buildFilter() {
    final minLatRaw = _parseCoord(_minLatController.text);
    final maxLatRaw = _parseCoord(_maxLatController.text);
    final minLngRaw = _parseCoord(_minLngController.text);
    final maxLngRaw = _parseCoord(_maxLngController.text);

    final anyFilled = [minLatRaw, maxLatRaw, minLngRaw, maxLngRaw].any((v) => v != null);
    final allFilled = [minLatRaw, maxLatRaw, minLngRaw, maxLngRaw].every((v) => v != null);

    if (anyFilled && !allFilled) {
      _showError('Fill all four coordinate fields or leave them all empty');
      return null;
    }

    final minLat = minLatRaw ?? -90.0;
    final maxLat = maxLatRaw ?? 90.0;
    final minLng = minLngRaw ?? -180.0;
    final maxLng = maxLngRaw ?? 180.0;

    if (minLat < -90 || minLat > 90 || maxLat < -90 || maxLat > 90) {
      _showError('Latitude must be between -90 and 90');
      return null;
    }
    if (minLng < -180 || minLng > 180 || maxLng < -180 || maxLng > 180) {
      _showError('Longitude must be between -180 and 180');
      return null;
    }
    if (minLat >= maxLat) {
      _showError('Min latitude must be less than max latitude');
      return null;
    }
    if (minLng >= maxLng) {
      _showError('Min longitude must be less than max longitude');
      return null;
    }
    if (!_startDate.isBefore(_endDate)) {
      _showError('Start date must be before end date');
      return null;
    }

    return StatisticsFilter(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  Future<void> _selectDateRange() async {
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
        _dateRangeController.text =
            '${DateFormat('yyyy-MM-dd').format(_startDate)} – ${DateFormat('yyyy-MM-dd').format(_endDate)}';
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _resetFilters() {
    setState(() {
      _startDate = DateTime.now().subtract(const Duration(days: 30));
      _endDate = DateTime.now();
      _minLatController.clear();
      _maxLatController.clear();
      _minLngController.clear();
      _maxLngController.clear();
      _dateRangeController.text =
          '${DateFormat('yyyy-MM-dd').format(_startDate)} – ${DateFormat('yyyy-MM-dd').format(_endDate)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _resetFilters,
                  tooltip: 'Reset filters',
                ),
              ],
            ),
            const SizedBox(height: 16),

            ExpansionTile(
              title: const Text('Geographic Area'),
              subtitle: const Text(
                'Leave empty to include all locations',
                style: TextStyle(fontSize: 12),
              ),
              initiallyExpanded: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minLatController,
                              decoration: const InputDecoration(
                                labelText: 'South (min lat)',
                                hintText: 'e.g. 40.5',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _maxLatController,
                              decoration: const InputDecoration(
                                labelText: 'North (max lat)',
                                hintText: 'e.g. 41.0',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minLngController,
                              decoration: const InputDecoration(
                                labelText: 'West (min lng)',
                                hintText: 'e.g. -74.1',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _maxLngController,
                              decoration: const InputDecoration(
                                labelText: 'East (max lng)',
                                hintText: 'e.g. -73.9',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ExpansionTile(
              title: const Text('Time Range'),
              initiallyExpanded: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: TextField(
                    controller: _dateRangeController,
                    decoration: const InputDecoration(
                      labelText: 'Date range',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: _selectDateRange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final filter = _buildFilter();
                  if (filter != null) widget.onFilterChanged(filter);
                },
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
