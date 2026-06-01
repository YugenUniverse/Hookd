import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/statistics_filter.dart';
import '../models/wall.dart';
import '../providers/statistics_provider.dart';
import '../services/api_service.dart';
import '../widgets/poi_map.dart';
import '../widgets/statistics_filter_widget.dart';

/// Page for viewing and filtering statistics by geographic area and time range
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
    print('📍 Filter applied: $filter');
    final statsProvider = Provider.of<StatisticsProvider>(
      context,
      listen: false,
    );

    try {
      statsProvider.setLoading(true);
      statsProvider.setError(null);

      print('🔄 Fetching statistics...');
      final stats = await _fetchStatistics(filter);
      print('✅ Got stats: ${stats.keys}');

      if (!mounted) return;
      statsProvider.setFilter(filter);
      statsProvider.setStats(stats);

      if (stats['wallList'] != null && stats['wallList'].isNotEmpty) {
        _updateMapWithWalls(stats['wallList']);
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ Error: $e');
      statsProvider.setError(e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        statsProvider.setLoading(false);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchStatistics(StatisticsFilter filter) async {
    return ApiService().getStatisticsByAreaAndTime(filter);
  }

  void _updateMapWithWalls(List<dynamic> wallList) {
    if (wallList.isEmpty) return;
    final first = wallList.first;
    if (first is! Map) return;
    final loc = first['location'];
    if (loc == null) return;
    final wall = Wall(
      id: first['id'] ?? '',
      name: first['name'] ?? 'Unknown',
      latitude: (loc['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (loc['longitude'] as num?)?.toDouble() ?? 0.0,
      difficulty: 'UNKNOWN',
      description: '',
      wallType: 'OutdoorWall',
      sessions: const [],
      issues: const [],
    );
    _mapController.focusOnWall(wall);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geographic Analytics')),
      body: Column(
        children: [
          // Filter widget (expandable section)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: ExpansionTile(
              title: const Text(
                'Filters',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              initiallyExpanded: true,
              children: [
                StatisticsFilterWidget(onFilterChanged: _onFilterApplied),
              ],
            ),
          ),
          // Map + Stats in split view
          Expanded(
            child: Row(
              children: [
                // Map (left, 40%)
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: POIMap(controller: _mapController),
                  ),
                ),
                // Stats (right, 60%)
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
                                const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Error',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Area summary
          _statCard(
            title: 'Area Summary',
            children: [
              _statRow('Walls in area', '${stats['wallCount'] ?? 0}'),
              if (stats['area'] != null)
                _statRow(
                  'Area bounds',
                  stats['area'] is String ? stats['area'] : 'Unknown',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Engagement metrics
          _statCard(
            title: 'Engagement',
            children: [
              _statRow(
                'Total Sessions',
                '${stats['engagement']?['totalSessions'] ?? 0}',
                highlight: true,
              ),
              _statRow(
                'Unique Climbers',
                '${stats['engagement']?['uniqueClimbers'] ?? 0}',
              ),
              _statRow(
                'Avg Time (min)',
                '${stats['engagement']?['avgTimeMins']?.toStringAsFixed(1) ?? 0}',
              ),
              _statRow(
                'Total Sends',
                '${stats['engagement']?['totalSends'] ?? 0}',
              ),
              _statRow(
                'Retention Rate',
                '${(stats['engagement']?['retentionRate'] as num? ?? 0).toStringAsFixed(1)}%',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quality metrics
          _statCard(
            title: 'Quality',
            children: [
              _statRow(
                'Avg Rating',
                '${stats['quality']?['avgRating']?.toStringAsFixed(1) ?? 0}/5',
                highlight: true,
              ),
              _statRow(
                'Total Reviews',
                '${stats['quality']?['totalReviews'] ?? 0}',
              ),
            ],
          ),
        ],
      ),
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
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
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
