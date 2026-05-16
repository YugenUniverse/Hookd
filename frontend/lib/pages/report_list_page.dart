import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../models/report.dart';
import 'report_detail_page.dart';
import 'live_report_page.dart';

class ReportListPage extends StatefulWidget {
  final ReportService reportService;

  const ReportListPage({super.key, required this.reportService});

  @override
  _ReportListPageState createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage> {
  late Future<List<Report>> _futureSavedReports;

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

  // --- THE NEW REPORT FLOW: WALL SELECTOR ---
  void _openNewReportSelector() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Wall for Live Analysis',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: widget.reportService.getFacilityWalls(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError)
                      return const Center(
                        child: Text('Error downloading wall profiles.'),
                      );
                    if (!snapshot.hasData || snapshot.data!.isEmpty)
                      return const Center(
                        child: Text(
                          'No active walls found. Create a wall profile first.',
                        ),
                      );

                    final walls = snapshot.data!;
                    return ListView.builder(
                      itemCount: walls.length,
                      itemBuilder: (context, index) {
                        final wall = walls[index];
                        final wallId = wall['id'] ?? wall['_id'];
                        final wallName = wall['name'] ?? 'Unnamed Wall';

                        return ListTile(
                          leading: const Icon(
                            Icons.terrain_rounded,
                            color: Colors.blueAccent,
                          ),
                          title: Text(
                            wallName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            Navigator.pop(context); // Dismiss sheet safely

                            // Navigate to Live Analytics view
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
                            _fetchHistory(); // Refresh history timeline when returning
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance Analytics')),

      // 👇 TRIPPED BY COMPONENT REQUEST: FAB TO LOAD SELECTOR
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewReportSelector,
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),

      body: FutureBuilder<List<Report>>(
        future: _futureSavedReports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return const Center(
              child: Text('Failed to load performance archive.'),
            );
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
                    "${report.createdAt.toLocal().toString().split(' ')[0]}\n${report.notes}",
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
