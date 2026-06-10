import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Filter model for geographic area and time range
class StatisticsFilter {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final DateTime startDate;
  final DateTime endDate;

  StatisticsFilter({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.startDate,
    required this.endDate,
  });

  /// Validate geographic bounds
  bool isValidGeoBounds() {
    return minLat < maxLat && minLng < maxLng;
  }

  /// Validate time range
  bool isValidTimeRange() {
    return startDate.isBefore(endDate);
  }

  /// Convert to query parameters for API
  Map<String, String> toQueryParams() {
    return {
      'minLat': minLat.toString(),
      'maxLat': maxLat.toString(),
      'minLng': minLng.toString(),
      'maxLng': maxLng.toString(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'StatisticsFilter(bounds: [$minLat,$maxLat] x [$minLng,$maxLng], '
        'dates: ${DateFormat('yyyy-MM-dd').format(startDate)} - ${DateFormat('yyyy-MM-dd').format(endDate)})';
  }
}
