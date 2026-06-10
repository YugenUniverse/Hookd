import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../models/report.dart';
import 'live_report_page.dart';
import 'report_detail_page.dart';

class ReportListPage extends StatefulWidget {
  final ReportService reportService;

  const ReportListPage({super.key, required this.reportService});

  @override
  ReportListPageState createState() => ReportListPageState();
}

class ReportListPageState extends State<ReportListPage> {
  late Future<List<Report>> _futureSavedReports;
  bool _groupReportMode = false;
  final Set<String> _selectedWallIds = {};

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  void _fetchHistory() {
    setState(() {
      _futureSavedReports = widget.reportService.getAllSavedReports();
    });
  }

  void _openNewReportSelector() async {
    final wallsFuture = widget.reportService.getWalls();
    final scrollController = ScrollController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose report flow',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Single Wall'),
                          selected: !_groupReportMode,
                          onSelected: (_) {
                            setState(() {
                              _groupReportMode = false;
                              _selectedWallIds.clear();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Group Report'),
                          selected: _groupReportMode,
                          onSelected: (_) {
                            setState(() {
                              _groupReportMode = true;
                              _selectedWallIds.clear();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_groupReportMode)
                    Text(
                      'Select two or more walls',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (_groupReportMode) const SizedBox(height: 8),
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: wallsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text('Error downloading wall profiles.'),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text(
                              'No active walls found. Create a wall profile first.',
                            ),
                          );
                        }

                        final walls = snapshot.data!;
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: walls.length,
                          itemBuilder: (context, index) {
                            final wall = walls[index];
                            final wallId = wall['id'] ?? wall['_id'];
                            final wallName = wall['name'] ?? 'Unnamed Wall';
                            final isSelected = _selectedWallIds.contains(
                              wallId,
                            );

                            if (_groupReportMode) {
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedWallIds.add(wallId);
                                    } else {
                                      _selectedWallIds.remove(wallId);
                                    }
                                  });
                                },
                                title: Text(
                                  wallName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                secondary: Icon(
                                  Icons.terrain_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              );
                            }

                            return ListTile(
                              leading: Icon(
                                Icons.terrain_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                wallName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LiveReportPage(
                                      wallId: wallId,
                                      wallName: wallName,
                                      reportService: widget.reportService,
                                    ),
                                  ),
                                );
                                _fetchHistory();
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (_groupReportMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: FilledButton(
                        onPressed: _selectedWallIds.length < 2
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LiveReportPage(
                                      wallIds: _selectedWallIds.toList(),
                                      wallName:
                                          'Multiple Walls (${_selectedWallIds.length})',
                                      reportService: widget.reportService,
                                    ),
                                  ),
                                );
                                _fetchHistory();
                              },
                        child: Text(
                          _selectedWallIds.length < 2
                              ? 'Select at least 2 walls'
                              : 'Open grouped report (${_selectedWallIds.length})',
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance Analytics')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewReportSelector,
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
      ),
      body: FutureBuilder<List<Report>>(
        future: _futureSavedReports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load performance archive.'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Archive Empty.\nTap "New Report" to view and freeze live wall data.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final reports = snapshot.data!;
          return ListView.builder(
            itemCount: reports.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: const Icon(
                    Icons.analytics_outlined,
                    color: Colors.blueAccent,
                  ),
                  title: Text(
                    report.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    report.walls != null && report.walls!.isNotEmpty
                        ? "${report.createdAt.toLocal().toString().split(' ')[0]} • ${report.walls!.length} walls\n${report.notes}"
                        : "${report.createdAt.toLocal().toString().split(' ')[0]}\n${report.notes}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReportDetailPage(
                          reportId: report.id,
                          reportService: widget.reportService,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
