import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/report_service.dart';
import '../models/report.dart';
import 'report_detail_page.dart';

class LiveReportPage extends StatefulWidget {
  final String? wallId;
  final List<String>? wallIds;
  final String wallName;
  final ReportService reportService;

  const LiveReportPage({
    super.key,
    this.wallId,
    this.wallIds,
    required this.wallName,
    required this.reportService,
  }) : assert(wallId != null || wallIds != null);

  @override
  LiveReportPageState createState() => LiveReportPageState();
}

class LiveReportPageState extends State<LiveReportPage> {
  late Future<ReportData> futureLiveReport;
  late bool _isGrouped;
  int _selectedChartIndex = 0;

  String _percentageLabel(num part, num total) {
    if (total <= 0) return '0%';
    return '${((part / total) * 100).toInt()}%';
  }

  @override
  void initState() {
    super.initState();
    _isGrouped = widget.wallIds != null && widget.wallIds!.isNotEmpty;
    futureLiveReport = _isGrouped
        ? widget.reportService.getLiveGroupReport(widget.wallIds!)
        : widget.reportService.getLiveReport(widget.wallId!);
  }

  String _formatMetric(num value, {int decimals = 2}) {
    return value.toStringAsFixed(decimals);
  }

  Future<void> _showSaveDialog() async {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                _isGrouped ? 'Save Group Report' : 'Freeze Live Snapshot',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isGrouped
                          ? 'Archive the grouped live metrics to the report history.'
                          : 'Save data metrics permanently to historical records.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Snapshot Title',
                        hintText: 'e.g., Q1 End Audit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Actions Taken',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) return;
                          setState(() => isSaving = true);
                          try {
                            if (_isGrouped) {
                              final savedReport = await widget.reportService
                                  .saveGroupReport(
                                    widget.wallIds!,
                                    titleController.text.trim(),
                                    notesController.text.trim(),
                                  );
                              if (!mounted) return;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                Navigator.pop(context);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReportDetailPage(
                                      reportId: savedReport.id,
                                      reportService: widget.reportService,
                                    ),
                                  ),
                                );
                              });
                            } else {
                              await widget.reportService.saveReportSnapshot(
                                widget.wallId!,
                                titleController.text.trim(),
                                notesController.text.trim(),
                              );
                              if (!mounted) return;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                Navigator.pop(context);
                                Navigator.pop(context);
                              });
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => isSaving = false);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _isGrouped
                                        ? 'Failed to save grouped report.'
                                        : 'Failed to cache performance log.',
                                  ),
                                ),
                              );
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isGrouped ? 'Archive Group' : 'Archive Snap'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isGrouped ? 'Group Diagnostics' : 'Live Diagnostics'),
            Text(
              widget.wallName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSaveDialog,
        icon: const Icon(Icons.save_rounded),
        label: const Text('Save Snapshot'),
      ),
      body: FutureBuilder<ReportData>(
        future: futureLiveReport,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Telemetry error occurred.'));
          }
          if (snapshot.data == null) {
            return const Center(child: Text('Metrics array unpopulated.'));
          }

          final data = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Live Metrics Engine',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

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

                const Text(
                  'Recent Feedback',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (data.recentFeedback.isEmpty)
                  const Text(
                    'No written feedback for this period.',
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
                const SizedBox(height: 32),

                if (_isGrouped && data.wallComparisons.isNotEmpty) ...[
                  const Text(
                    'Wall Comparison (Sessions)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: _buildWallComparisonChart(
                      context,
                      data.wallComparisons,
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
                      data.wallComparisons,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.wallComparisons.asMap().entries.map((entry) {
                      final comparison = entry.value;
                      final wallName = _wallComparisonLabel(
                        comparison,
                        entry.key,
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
                    final isOpen =
                        issue['status'] == 'OPEN' ||
                        issue['status'] == 'IN_PROGRESS';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          isOpen ? Icons.build_circle : Icons.check_circle,
                          color: isOpen ? Colors.orangeAccent : Colors.green,
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
                  'Live Traffic Stream',
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
                const SizedBox(height: 80),
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
    }
    if (_selectedChartIndex == 1) {
      return _buildHourBarChart(context, data.byHourOfDay);
    }
    return _buildDayBarChart(context, data.byDayOfWeek);
  }

  String _wallComparisonLabel(Map<String, dynamic> comparison, int index) {
    final storedName = comparison['wallName']?.toString();
    if (storedName != null && storedName.isNotEmpty) {
      return storedName;
    }

    final nestedName =
        (comparison['wall'] as Map?)?['name']?.toString() ??
        (comparison['wall'] as Map?)?['wallName']?.toString();
    if (nestedName != null && nestedName.isNotEmpty) {
      return nestedName;
    }

    return 'Wall ${index + 1}';
  }

  Widget _buildWallComparisonChart(
    BuildContext context,
    List<Map<String, dynamic>> wallComparisons,
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

  Widget _buildLegendItem(Color color, String text, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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

  Widget _buildSendRateChart(
    BuildContext context,
    int totalSends,
    int totalAttempts,
  ) {
    int total = totalSends + totalAttempts;
    if (total == 0) return const SizedBox.shrink();
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Send Rate',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 25,
              sections: [
                PieChartSectionData(
                  color: Colors.green,
                  value: totalSends.toDouble(),
                  title: _percentageLabel(totalSends, total),
                  radius: 30,
                  titleStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  color: Colors.redAccent,
                  value: totalAttempts.toDouble(),
                  title: _percentageLabel(totalAttempts, total),
                  radius: 30,
                  titleStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _buildLegendItem(Colors.green, 'Sends ($totalSends)', textColor),
            _buildLegendItem(
              Colors.redAccent,
              'Fails ($totalAttempts)',
              textColor,
            ),
          ],
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
    if (totalUsers <= 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Demographics',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 25,
              sections: List.generate(demographics.length, (i) {
                final count = demographics[i]['count'] as int;
                return PieChartSectionData(
                  color: colors[i % colors.length],
                  value: count.toDouble(),
                  title: _percentageLabel(count, totalUsers),
                  radius: 30,
                  titleStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(
            demographics.length,
            (i) => _buildLegendItem(
              colors[i % colors.length],
              demographics[i]['bracket'],
              textColor,
            ),
          ),
        ),
      ],
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
              getTitlesWidget: (v, m) => v.toInt() % 4 == 0
                  ? Text(
                      '${v.toInt()}h',
                      style: TextStyle(color: textColor, fontSize: 10),
                    )
                  : const SizedBox.shrink(),
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
    final counts = {for (var i in Iterable.generate(7)) i + 1: 0};
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
              getTitlesWidget: (v, m) =>
                  (v.toInt() - 1 >= 0 && v.toInt() - 1 < days.length)
                  ? Text(
                      days[v.toInt() - 1],
                      style: TextStyle(color: textColor, fontSize: 12),
                    )
                  : const SizedBox.shrink(),
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
              getTitlesWidget: (v, m) => SideTitleWidget(
                meta: m,
                child: Text(
                  '${v.toInt()}★',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, m) => v == v.toInt().toDouble()
                  ? Text(
                      v.toInt().toString(),
                      style: TextStyle(fontSize: 12, color: textColor),
                    )
                  : const SizedBox.shrink(),
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
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
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
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: dateInterval,
              getTitlesWidget: (v, m) {
                if (v.toInt() >= 0 && v.toInt() < trends.length) {
                  final parts = (trends[v.toInt()]['date'] as String).split(
                    '-',
                  );
                  if (parts.length >= 3) {
                    return SideTitleWidget(
                      meta: m,
                      child: Text(
                        '${parts[1]}/${parts[2]}',
                        style: TextStyle(fontSize: 11, color: textColor),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, m) => v == v.toInt().toDouble()
                  ? Text(
                      v.toInt().toString(),
                      style: TextStyle(fontSize: 12, color: textColor),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
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
              color: Colors.blueAccent.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}
