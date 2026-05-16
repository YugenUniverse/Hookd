import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/report_service.dart';
import '../models/report.dart';

class ReportDetailPage extends StatefulWidget {
  final String reportId;
  final ReportService reportService;

  const ReportDetailPage({
    super.key,
    required this.reportId,
    required this.reportService,
  });

  @override
  _ReportDetailPageState createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late Future<Report> futureReport;

  // Tracks which temporal chart is currently visible (0 = 30-Day, 1 = Hours, 2 = Days)
  int _selectedChartIndex = 0;

  @override
  void initState() {
    super.initState();
    futureReport = widget.reportService.getReportDetails(widget.reportId);
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HEADER
                Text(
                  report.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // KPIS
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
                      '${data.engagement['retentionRate']}x',
                      Icons.repeat,
                    ),
                    _buildKpiCard(
                      context,
                      'Avg Time',
                      '${data.engagement['avgTimeMins']}m',
                      Icons.timer,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // SEND RATE + DEMOGRAPHICS
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

                // RATINGS CHART
                const Text(
                  'Quality Distribution',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

                // RECENT FEEDBACK
                const Text(
                  'Recent Feedback',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

                // TRENDS SWITCHER SECTION
                const Text(
                  'Traffic & Trends',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

                // DYNAMIC CHART CONTAINER
                SizedBox(height: 250, child: _buildDynamicChart(context, data)),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // Determines which chart to render based on the Segmented Button
  Widget _buildDynamicChart(BuildContext context, ReportData data) {
    if (_selectedChartIndex == 0) {
      return _buildTrafficLineChart(context, data.trends);
    } else if (_selectedChartIndex == 1) {
      return _buildHourBarChart(context, data.byHourOfDay);
    } else {
      return _buildDayBarChart(context, data.byDayOfWeek);
    }
  }

  // ==========================================
  // WIDGET HELPERS (Charts & Cards)
  // ==========================================

  Widget _buildKpiCard(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    Color color = Colors.blue,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final red = color.r.round();
    final green = color.g.round();
    final blue = color.b.round();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Color.fromRGBO(red, green, blue, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color.fromRGBO(red, green, blue, 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
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
        maxY: maxY, // Fixes glitch if empty
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

    // Explicitly calculate MaxY to prevent the infinite grid glitch
    final maxY = (counts.values.reduce((a, b) => a > b ? a : b).toDouble()) + 2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY, // Fixes glitch if empty
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
    if (trends.isEmpty) return const Center(child: Text('Not enough data'));

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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        Text(
                          'Sends ($totalSends)',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
                        Text(
                          'Fails ($totalAttempts)',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Climber Demographics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
