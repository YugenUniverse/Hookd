import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/statistics_filter.dart';
import '../providers/statistics_provider.dart';
import '../services/api_service.dart';
import '../widgets/poi_map.dart';
import '../widgets/statistics_filter_widget.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final WallMapController _mapController = WallMapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onFilterApplied(StatisticsFilter filter) async {
    if (!mounted) return;
    final statsProvider = Provider.of<StatisticsProvider>(context, listen: false);

    try {
      statsProvider.setLoading(true);
      statsProvider.setError(null);

      final stats = await ApiService().getStatisticsByAreaAndTime(filter);

      if (!mounted) return;
      statsProvider.setFilter(filter);
      statsProvider.setStats(stats);

      _mapController.focusBbox(filter.minLat, filter.maxLat, filter.minLng, filter.maxLng);
    } catch (e) {
      if (!mounted) return;
      statsProvider.setError(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) statsProvider.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geographic Analytics')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: ExpansionTile(
              title: const Text('Filters', style: TextStyle(fontWeight: FontWeight.w600)),
              initiallyExpanded: true,
              children: [
                StatisticsFilterWidget(
                  onFilterChanged: _onFilterApplied,
                  onPreviewChanged: (f) => _mapController.focusBbox(
                    f.minLat, f.maxLat, f.minLng, f.maxLng,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: POIMap(controller: _mapController),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Consumer<StatisticsProvider>(
                    builder: (context, statsProvider, _) {
                      if (statsProvider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (statsProvider.error != null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 32),
                                const SizedBox(height: 12),
                                Text(
                                  'Error',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  statsProvider.error ?? 'Unknown error',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (statsProvider.currentStats == null) {
                        return Center(
                          child: Text(
                            'Select filters and apply to view statistics',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        );
                      }

                      return _buildStatisticsView(statsProvider.currentStats!);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsView(Map<String, dynamic> stats) {
    final trends = stats['trends'] as Map<String, dynamic>?;
    final byDate = (trends?['byDate'] as List?) ?? [];
    final byDayOfWeek = (trends?['byDayOfWeek'] as List?) ?? [];
    final distribution = (stats['quality']?['distribution'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statCard(
            title: 'Area Summary',
            children: [
              _statRow('Walls in area', '${stats['wallCount'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 12),

          _statCard(
            title: 'Engagement',
            children: [
              _statRow('Total Sessions', '${stats['engagement']?['totalSessions'] ?? 0}', highlight: true),
              _statRow('Unique Climbers', '${stats['engagement']?['uniqueClimbers'] ?? 0}'),
              _statRow('Avg Time (min)', '${stats['engagement']?['avgTimeMins']?.toStringAsFixed(1) ?? 0}'),
              _statRow('Total Sends', '${stats['engagement']?['totalSends'] ?? 0}'),
              _statRow('Retention Rate', '${(stats['engagement']?['retentionRate'] as num? ?? 0).toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 12),

          _statCard(
            title: 'Quality',
            children: [
              _statRow('Avg Rating', '${stats['quality']?['avgRating']?.toStringAsFixed(1) ?? 0}/5', highlight: true),
              _statRow('Total Reviews', '${stats['quality']?['totalReviews'] ?? 0}'),
            ],
          ),

          if (byDate.length >= 2) ...[
            const SizedBox(height: 12),
            _buildSessionsOverTimeChart(byDate),
          ],

          if (byDayOfWeek.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDayOfWeekChart(byDayOfWeek),
          ],

          if (distribution.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildRatingDistributionChart(distribution),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionsOverTimeChart(List<dynamic> byDate) {
    final spots = byDate.asMap().entries.map((e) {
      final entry = e.value as Map<String, dynamic>;
      return FlSpot(e.key.toDouble(), (entry['sessions'] as num?)?.toDouble() ?? 0);
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final interval = max(1, (byDate.length / 5).ceil()).toDouble();

    return _statCard(
      title: 'Sessions Over Time',
      children: [
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 2,
                  dotData: FlDotData(show: spots.length <= 20),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
              minY: 0,
              maxY: maxY + 1,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: interval,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= byDate.length) return const SizedBox.shrink();
                      final dateStr = (byDate[idx] as Map)['date'] as String? ?? '';
                      if (dateStr.length < 10) return const SizedBox.shrink();
                      return Text(dateStr.substring(5), style: const TextStyle(fontSize: 9));
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayOfWeekChart(List<dynamic> byDayOfWeek) {
    // MongoDB $dayOfWeek: 1=Sunday, 2=Monday, ..., 7=Saturday
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final countByDay = <int, double>{};
    for (final d in byDayOfWeek) {
      final entry = d as Map<String, dynamic>;
      final day = (entry['day'] as num?)?.toInt() ?? 0;
      countByDay[day] = (entry['count'] as num?)?.toDouble() ?? 0;
    }

    final groups = List.generate(7, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: countByDay[i + 1] ?? 0,
            color: Theme.of(context).colorScheme.primary,
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

    return _statCard(
      title: 'Activity by Day',
      children: [
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              barGroups: groups,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, _) => Text(
                      dayLabels[v.toInt().clamp(0, 6)],
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingDistributionChart(List<dynamic> distribution) {
    final countByStar = <int, double>{};
    for (final d in distribution) {
      final entry = d as Map<String, dynamic>;
      final stars = (entry['stars'] as num?)?.toInt() ?? 0;
      countByStar[stars] = (entry['count'] as num?)?.toDouble() ?? 0;
    }

    final groups = List.generate(5, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: countByStar[i + 1] ?? 0,
            color: Colors.amber,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

    return _statCard(
      title: 'Rating Distribution',
      children: [
        SizedBox(
          height: 140,
          child: BarChart(
            BarChartData(
              barGroups: groups,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, _) {
                      const labels = ['1★', '2★', '3★', '4★', '5★'];
                      return Text(labels[v.toInt().clamp(0, 4)], style: const TextStyle(fontSize: 11));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String value, {bool highlight = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
