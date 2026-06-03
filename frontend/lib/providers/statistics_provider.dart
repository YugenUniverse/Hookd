import 'package:flutter/material.dart';

import '../models/statistics_filter.dart';

/// Provider for managing statistics and filters across the app
class StatisticsProvider extends ChangeNotifier {
  StatisticsFilter? _currentFilter;
  Map<String, dynamic>? _currentStats;
  bool _isLoading = false;
  String? _error;

  StatisticsFilter? get currentFilter => _currentFilter;
  Map<String, dynamic>? get currentStats => _currentStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setFilter(StatisticsFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  void setStats(Map<String, dynamic> stats) {
    _currentStats = stats;
    _error = null;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearStats() {
    _currentStats = null;
    _currentFilter = null;
    _error = null;
    notifyListeners();
  }
}
