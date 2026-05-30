import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/report_service.dart';
import '../models/report.dart';
import '../utils/download_csv_helper.dart';

class ReportDetailPage extends StatefulWidget {
  final String reportId;
  final ReportService reportService;

  const ReportDetailPage({
    super.key,
    required this.reportId,
    required this.reportService,
  });

  @override
  ReportDetailPageState createState() => ReportDetailPageState();
}

class ReportDetailPageState extends State<ReportDetailPage> {
  late Future<Report> futureReport;
  int _selectedChartIndex = 0;
  bool _isExporting = false;
  final Set<String> _selectedCsvSections = {};

  @override
  void initState() {
    super.initState();
    futureReport = widget.reportService.getReportDetails(widget.reportId);
  }

  String _formatMetric(num value, {int decimals = 2}) {
    return value.toStringAsFixed(decimals);
  }

  Widget _buildExportButton(BuildContext context, Report report) {
    final colorScheme = Theme.of(context).colorScheme;
    final availableSections = _availableExportSections(report);
    final selectedSections = _selectedCsvSections.isEmpty
        ? availableSections.toSet()
        : _selectedCsvSections;

    return FilledButton.icon(
      onPressed: _isExporting
          ? null
          : () async {
              setState(() {
                _isExporting = true;
              });

              final messenger = ScaffoldMessenger.of(context);

              try {
                final exportSections =
                    selectedSections.length == availableSections.length
                    ? null
                    : selectedSections.toList();
                final csvContent = await widget.reportService.exportReportCsv(
                  report.id,
                  sections: exportSections,
                );
                final safeTitle = report.title
                    .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
                    .replaceAll(RegExp(r'_+'), '_')
                    .replaceAll(RegExp(r'^_+|_+?$'), '')
                    .trim();
                final fileName =
                    '${safeTitle.isEmpty ? 'report' : safeTitle}-${DateTime.now().toIso8601String().substring(0, 10)}.csv';

                downloadCsvFile(fileName, csvContent);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('CSV exported as $fileName')),
                  );
                }
              } catch (error) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to export CSV: $error')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isExporting = false;
                  });
                }
              }
            },
      icon: _isExporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.download_rounded, size: 18),
      label: Text(_isExporting ? 'Exporting...' : 'Export CSV'),
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  List<String> _availableExportSections(Report report) {
    final sections = [
      'engagement',
      'quality',
      'trends',
      'feedback',
      'issues',
      'demographics',
    ];

    if ((report.reportData?.wallComparisons ?? []).isNotEmpty) {
      sections.add('wallComparisons');
    }

    return sections;
  }

  String _sectionLabel(String section) {
    const labels = {
      'engagement': 'Engagement',
      'quality': 'Quality',
      'trends': 'Trends',
      'feedback': 'Feedback',
      'issues': 'Issues',
      'demographics': 'Demographics',
      'wallComparisons': 'Wall comparisons',
    };

    return labels[section] ?? section;
  }

  Widget _buildExportControls(BuildContext context, Report report) {
    final colorScheme = Theme.of(context).colorScheme;
    final availableSections = _availableExportSections(report);
    final hasWallComparisons =
        (report.reportData?.wallComparisons ?? []).isNotEmpty;
    final displaySections = [
      'engagement',
      'quality',
      'trends',
      'feedback',
      'issues',
      'demographics',
      'wallComparisons',
    ];
    final selectedSections = _selectedCsvSections.isEmpty
        ? availableSections.toSet()
        : _selectedCsvSections;
    final normalizedSelection = selectedSections.toSet()
      ..removeWhere(
        (section) => section == 'wallComparisons' && !hasWallComparisons,
      );
    final allSelected = normalizedSelection.length == availableSections.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.download_rounded,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export CSV',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pick sections, then download the saved report snapshot.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildExportButton(context, report),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Sections',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  allSelected
                      ? 'All selected'
                      : '${normalizedSelection.length}/${availableSections.length} selected',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            multiSelectionEnabled: true,
            showSelectedIcon: true,
            segments: displaySections
                .map(
                  (section) => ButtonSegment<String>(
                    value: section,
                    label: Text(_sectionLabel(section)),
                  ),
                )
                .toList(),
            selected: normalizedSelection,
            onSelectionChanged: (newSelection) {
              final nextSelection = newSelection.toSet()
                ..removeWhere(
                  (section) =>
                      section == 'wallComparisons' && !hasWallComparisons,
                );
              setState(() {
                _selectedCsvSections
                  ..clear()
                  ..addAll(nextSelection);
              });
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              minimumSize: WidgetStateProperty.all(const Size(0, 40)),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return BorderSide(color: colorScheme.primary, width: 1.2);
                }
                return BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                );
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return colorScheme.primaryContainer;
                }
                return colorScheme.surface;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return colorScheme.onPrimaryContainer;
                }
                return colorScheme.onSurface;
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wall Analytics')),
      body: FutureBuilder<Report>(
        future: futureReport,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading data'));
          }

          final report = snapshot.data!;
          final data = report.reportData;

          if (data == null) {
            return const Center(child: Text('No analytics data available.'));
          }

          final wallNames =
              report.walls
                  ?.where((wall) => wall['name'] != null)
                  .map((wall) => wall['name'] as String)
                  .toList() ??
              [];
          final wallNameById = <String, String>{};
          for (final wall in report.walls ?? []) {
            final wallId = (wall['id'] ?? wall['_id'])?.toString();
            final wallName = wall['name']?.toString();
            if (wallId != null && wallName != null && wallName.isNotEmpty) {
              wallNameById[wallId] = wallName;
            }
          }
          final wallComparisons = data.wallComparisons.map((comparison) {
            final normalized = Map<String, dynamic>.from(comparison);
            final wallId = (normalized['wallId'] ?? normalized['wall_id'])
                ?.toString();
            if ((normalized['wallName']?.toString() ?? '').isEmpty &&
                wallId != null) {
              final derivedName = wallNameById[wallId];
              if (derivedName != null && derivedName.isNotEmpty) {
                normalized['wallName'] = derivedName;
              }
            }
            return normalized;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (report.notes.isNotEmpty)
                            Text(
                              report.notes,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildExportControls(context, report),
                const SizedBox(height: 16),
                if (wallNames.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: wallNames.map((wallName) {
                      return Chip(
                        label: Text(wallName),
                        avatar: const Icon(Icons.terrain_rounded, size: 18),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                GridView.extent(
                  maxCrossAxisExtent: 200,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildKpiCard(
                      context,
                      'Total Sessions',
                      data.engagement['totalSessions'].toString(),
                      Icons.people,
                    ),
                    _buildKpiCard(
                      context,
                      'Unique Climbers',
                      data.engagement['uniqueClimbers'].toString(),
                      Icons.person_search,
                    ),
                    _buildKpiCard(
                      context,
                      'Retention',
                      '${_formatMetric((data.engagement['retentionRate'] ?? 0) as num)}x',
                      Icons.repeat,
                    ),
                    _buildKpiCard(
                      context,
                      'Avg Time',
                      '${_formatMetric((data.engagement['avgTimeMins'] ?? 0) as num)}m',
                      Icons.timer,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSendRateChart(
                        context,
                        data.engagement['totalSends'] ?? 0,
                        data.engagement['totalAttempts'] ?? 0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDemographicsChart(
                        context,
                        data.demographics,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                const Text(
                  'Quality Distribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 200,
                  child: _buildReviewBarChart(
                    context,
                    data.quality['distribution'] ?? [],
                  ),
                ),
                const SizedBox(height: 32),

                if (wallComparisons.isNotEmpty) ...[
                  const Text(
                    'Wall Comparison (Sessions)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: _buildWallComparisonChart(
                      context,
                      wallComparisons,
                      wallNameById,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Average Rating Comparison',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: _buildRatingComparisonChart(
                      context,
                      wallComparisons,
                      wallNameById,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: wallComparisons.map((comparison) {
                      final wallName = _wallComparisonLabel(
                        comparison,
                        wallComparisons.indexOf(comparison),
                        wallNameById,
                      );
                      final totalSessions =
                          (comparison['engagement']['totalSessions'] ?? 0)
                              as num;
                      final avgRating =
                          (comparison['quality']['avgRating'] ?? 0) as num;
                      return Chip(
                        label: Text(
                          '$wallName • ${totalSessions.toInt()} sessions • ${_formatMetric(avgRating)}★',
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],

                const Text(
                  'Recent Feedback',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (data.recentFeedback.isEmpty)
                  const Text(
                    "No written feedback for this period.",
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  ...data.recentFeedback.map(
                    (f) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Text(
                          '${f['rating']}★',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.amber,
                          ),
                        ),
                        title: Text(f['body']),
                        subtitle: Text(f['date']),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),

                const Text(
                  'Recent Issues',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (data.recentIssues.isEmpty)
                  const Text(
                    "No reported issues for this period.",
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  ...data.recentIssues.map((issue) {
                    final isOpen = issue['status'] == 'OPEN';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          isOpen
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: isOpen ? Colors.orange : Colors.green,
                          size: 28,
                        ),
                        title: Text(issue['body']),
                        subtitle: Text(
                          'Status: ${issue['status']} • ${issue['date']}',
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 40),

                const Text(
                  'Traffic & Trends',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('30 Days', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.show_chart, size: 16),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Hours', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.access_time, size: 16),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('Days', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.calendar_today, size: 16),
                    ),
                  ],
                  selected: {_selectedChartIndex},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() {
                      _selectedChartIndex = newSelection.first;
                    });
                  },
                ),

                const SizedBox(height: 24),
                SizedBox(height: 250, child: _buildDynamicChart(context, data)),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDynamicChart(BuildContext context, ReportData data) {
    if (_selectedChartIndex == 0) {
      return _buildTrafficLineChart(context, data.trends);
    } else if (_selectedChartIndex == 1) {
      return _buildHourBarChart(context, data.byHourOfDay);
    } else {
      return _buildDayBarChart(context, data.byDayOfWeek);
    }
  }

  String _wallComparisonLabel(
    Map<String, dynamic> comparison,
    int index,
    Map<String, String> wallNameById,
  ) {
    final storedName = comparison['wallName']?.toString();
    if (storedName != null && storedName.isNotEmpty) {
      return storedName;
    }

    final wallId = (comparison['wallId'] ?? comparison['wall_id'])?.toString();
    if (wallId != null) {
      final derivedName = wallNameById[wallId];
      if (derivedName != null && derivedName.isNotEmpty) {
        return derivedName;
      }
    }

    return 'Wall ${index + 1}';
  }

  Widget _buildWallComparisonChart(
    BuildContext context,
    List<Map<String, dynamic>> wallComparisons,
    Map<String, String> wallNameById,
  ) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final maxSessions = wallComparisons
        .map(
          (comparison) =>
              (comparison['engagement']['totalSessions'] ?? 0) as num,
        )
        .fold<num>(
          0,
          (previousValue, element) =>
              previousValue > element ? previousValue : element,
        )
        .toDouble();

    return ClipRect(
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxSessions == 0 ? 5 : maxSessions + (maxSessions * 0.2),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= wallComparisons.length) {
                    return const SizedBox.shrink();
                  }
                  final label = _wallComparisonLabel(
                    wallComparisons[index],
                    index,
                    wallNameById,
                  );
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      label.length > 14 ? '${label.substring(0, 12)}…' : label,
                      style: TextStyle(color: textColor, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: textColor),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(wallComparisons.length, (index) {
            final comparison = wallComparisons[index];
            final totalSessions =
                ((comparison['engagement']['totalSessions'] ?? 0) as num)
                    .toDouble();
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: totalSessions,
                  color: Colors.deepPurpleAccent,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRatingComparisonChart(
    BuildContext context,
    List<Map<String, dynamic>> wallComparisons,
    Map<String, String> wallNameById,
  ) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return ClipRect(
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 5,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= wallComparisons.length) {
                    return const SizedBox.shrink();
                  }
                  final label = _wallComparisonLabel(
                    wallComparisons[index],
                    index,
                    wallNameById,
                  );
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      label.length > 14 ? '${label.substring(0, 12)}…' : label,
                      style: TextStyle(color: textColor, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: textColor),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(wallComparisons.length, (index) {
            final comparison = wallComparisons[index];
            final avgRating = ((comparison['quality']['avgRating'] ?? 0) as num)
                .toDouble();
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: avgRating.clamp(0.0, 5.0),
                  color: Colors.amber,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;
    final textColor = colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: effectiveColor, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: effectiveColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourBarChart(BuildContext context, List<dynamic> hourData) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final counts = {for (var i in Iterable.generate(24)) i: 0};
    for (var item in hourData) {
      counts[item['hour'] as int] = item['count'] as int;
    }

    final maxY = (counts.values.reduce((a, b) => a > b ? a : b).toDouble()) + 2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 4 == 0) {
                  return Text(
                    '${value.toInt()}h',
                    style: TextStyle(color: textColor, fontSize: 10),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barGroups: counts.entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.toDouble(),
                    color: Colors.lightBlueAccent,
                    width: 8,
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDayBarChart(BuildContext context, List<dynamic> dayData) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final counts = {for (var i = 1; i <= 7; i++) i: 0};

    for (var item in dayData) {
      counts[item['day'] as int] = item['count'] as int;
    }

    final maxY = (counts.values.reduce((a, b) => a > b ? a : b).toDouble()) + 2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt() - 1;
                if (index >= 0 && index < days.length) {
                  return Text(
                    days[index],
                    style: TextStyle(color: textColor, fontSize: 12),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barGroups: counts.entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.toDouble(),
                    color: Colors.orangeAccent,
                    width: 20,
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildReviewBarChart(
    BuildContext context,
    List<dynamic> distribution,
  ) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    Map<int, int> starCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (var item in distribution) {
      starCounts[item['stars'] as int] = item['count'] as int;
    }

    double maxCount = starCounts.values
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    if (maxCount == 0) maxCount = 5;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxCount + (maxCount * 0.2),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (double value, TitleMeta meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${value.toInt()}★',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value == value.toInt().toDouble()) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 12, color: textColor),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withAlpha((255 * 0.2).round()),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 1; i <= 5; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: starCounts[i]!.toDouble(),
                  color: Colors.amber,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTrafficLineChart(BuildContext context, List<dynamic> trends) {
    if (trends.length <= 1) return const Center(child: Text('Not enough data'));

    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    List<FlSpot> spots = [];
    double maxSessions = 0;

    for (int i = 0; i < trends.length; i++) {
      double sessions = (trends[i]['sessions'] as num).toDouble();
      if (sessions > maxSessions) maxSessions = sessions;
      spots.add(FlSpot(i.toDouble(), sessions));
    }

    if (maxSessions == 0) maxSessions = 5;

    double dateInterval = (trends.length / 5).ceilToDouble();
    if (dateInterval == 0) dateInterval = 1;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withAlpha((255 * 0.2).round()),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: dateInterval,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < trends.length) {
                  final dateStr = trends[index]['date'] as String;
                  final parts = dateStr.split('-');
                  if (parts.length >= 3) {
                    final shortDate = '${parts[1]}/${parts[2]}';
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        shortDate,
                        style: TextStyle(fontSize: 11, color: textColor),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value == value.toInt().toDouble()) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 12, color: textColor),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: Colors.grey),
            left: BorderSide(color: Colors.grey),
          ),
        ),
        minX: 0,
        maxX: (trends.length - 1).toDouble(),
        minY: 0,
        maxY: maxSessions + (maxSessions * 0.2),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blueAccent.withAlpha((255 * 0.2).round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendRateChart(
    BuildContext context,
    int totalSends,
    int totalAttempts,
  ) {
    int total = totalSends + totalAttempts;
    if (total == 0) return const SizedBox.shrink();

    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    double sendPct = (totalSends / total) * 100;
    double attemptPct = (totalAttempts / total) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Send Rate (Success vs Attempts)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        color: Colors.green,
                        value: totalSends.toDouble(),
                        title: '${sendPct.toInt()}%',
                        radius: 40,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.redAccent,
                        value: totalAttempts.toDouble(),
                        title: '${attemptPct.toInt()}%',
                        radius: 40,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12, color: Colors.green),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Sends ($totalSends)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Fails ($totalAttempts)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
        ),
      ],
    );
  }

  Widget _buildDemographicsChart(
    BuildContext context,
    List<dynamic> demographics,
  ) {
    if (demographics.isEmpty) return const SizedBox.shrink();

    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final colors = [
      Colors.blueAccent,
      Colors.teal,
      Colors.orangeAccent,
      Colors.deepPurpleAccent,
    ];

    int totalUsers = 0;
    for (var d in demographics) {
      totalUsers += (d['count'] as int);
    }

    if (totalUsers == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Climber Demographics',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: List.generate(demographics.length, (i) {
                      final item = demographics[i];
                      final count = item['count'] as int;
                      final percentage = (count / totalUsers) * 100;

                      return PieChartSectionData(
                        color: colors[i % colors.length],
                        value: count.toDouble(),
                        title: '${percentage.toInt()}%',
                        radius: 40,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(demographics.length, (i) {
                    final item = demographics[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            color: colors[i % colors.length],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item['bracket'],
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
