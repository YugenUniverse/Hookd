import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/admin_metrics.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({Key? key}) : super(key: key);

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  late Future<AdminMetrics> _metricsFuture;
  final ApiService _apiService = ApiService();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _refreshMetrics();
  }

  void _refreshMetrics() {
    setState(() {
      _metricsFuture = _apiService.getAdminMetrics(
        startDate: _startDate,
        endDate: _endDate,
      );
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    DateTime tempStart =
        _startDate ?? DateTime.now().subtract(const Duration(days: 30));
    DateTime tempEnd = _endDate ?? DateTime.now();
    bool pickingStart = true;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Date Range'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setDialogState(() => pickingStart = true),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: pickingStart
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Start Date',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(tempStart),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setDialogState(() => pickingStart = false),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: !pickingStart
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'End Date',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(tempEnd),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: CalendarDatePicker(
                        initialDate: pickingStart ? tempStart : tempEnd,
                        firstDate: pickingStart ? DateTime(2020) : tempStart,
                        lastDate: pickingStart ? tempEnd : DateTime.now(),
                        onDateChanged: (DateTime newDate) {
                          setDialogState(() {
                            if (pickingStart) {
                              tempStart = newDate;
                              pickingStart = false; // switch to end date
                            } else {
                              tempEnd = newDate;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _startDate = tempStart;
        _endDate = tempEnd;
      });
      _refreshMetrics();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _refreshMetrics();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _refreshMetrics();
        await _metricsFuture;
      },
      child: FutureBuilder<AdminMetrics>(
        future: _metricsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Failed to load metrics: ${snapshot.error}'),
                  TextButton(
                    onPressed: _refreshMetrics,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasData) {
            final metrics = snapshot.data!;
            return SingleChildScrollView(
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Health',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryGrid(metrics),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _startDate != null && _endDate != null
                            ? 'Growth (${DateFormat('MMM d, y').format(_startDate!)} - ${DateFormat('MMM d, y').format(_endDate!)})'
                            : 'Growth (Last 12 Months)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (_startDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearDateRange,
                              tooltip: 'Clear filter',
                            ),
                          IconButton(
                            icon: const Icon(Icons.date_range),
                            onPressed: () => _selectDateRange(context),
                            tooltip: 'Filter by date',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildGraphs(metrics.graphs),
                  const SizedBox(height: 40), // Bottom padding
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSummaryGrid(AdminMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Active Users (30d)',
              metrics.activeUsers,
              Icons.local_fire_department,
              Colors.orange,
            ),
            _buildStatCard(
              'Total Users',
              metrics.totalUsers,
              Icons.people,
              Colors.blue,
            ),
            _buildStatCard(
              'Total Walls',
              metrics.totalWalls,
              Icons.terrain,
              Colors.green,
            ),
            _buildStatCard(
              'Total Reviews',
              metrics.totalReviews,
              Icons.star,
              Colors.amber,
            ),
            _buildStatCard(
              'Total Groups',
              metrics.totalGroups,
              Icons.group_work,
              Colors.purple,
            ),
            _buildStatCard(
              'Total Events',
              metrics.totalEvents,
              Icons.event,
              Colors.teal,
            ),
            _buildStatCard(
              'Open Reports',
              metrics.openReports,
              Icons.flag,
              Colors.red,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphs(AdminGraphs graphs) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildChartSection(
              'User Registrations',
              graphs.userRegistrations,
              Colors.blue,
            ),
            const Divider(height: 32),
            _buildChartSection(
              'Sessions Logged',
              graphs.sessionsLogged,
              Colors.orange,
            ),
            const Divider(height: 32),
            _buildChartSection(
              'Events Created',
              graphs.eventsCreated,
              Colors.teal,
            ),
            const Divider(height: 32),
            _buildChartSection(
              'Reviews Added',
              graphs.reviewsAdded,
              Colors.amber,
            ),
            const Divider(height: 32),
            _buildChartSection(
              'Groups Created',
              graphs.groupsCreated,
              Colors.purple,
            ),
            const Divider(height: 32),
            _buildChartSection('Walls Added', graphs.wallsAdded, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(
    String title,
    List<GraphDataPoint> data,
    Color color,
  ) {
    if (data.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Center(child: Text('No data available')),
        ],
      );
    }

    // Sort data chronologically just in case
    final sortedData = List<GraphDataPoint>.from(data)
      ..sort((a, b) {
        if (a.year == b.year) return a.month.compareTo(b.month);
        return a.year.compareTo(b.year);
      });

    // We need to map month/year to an X index for the chart
    final List<FlSpot> spots = [];
    double maxX = (sortedData.length - 1).toDouble();
    double maxY = 0;

    for (int i = 0; i < sortedData.length; i++) {
      double y = sortedData[i].count.toDouble();
      if (y > maxY) maxY = y;
      spots.add(FlSpot(i.toDouble(), y));
    }

    if (maxY == 0) maxY = 10; // default buffer

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index >= 0 && index < sortedData.length) {
                        final point = sortedData[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${point.month}/${point.year.toString().substring(2)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      if (value % 1 == 0) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: maxY + (maxY * 0.2), // 20% headroom
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
