class Report {
  final String id;
  final String title;
  final String notes;
  final DateTime createdAt;
  final Map<String, dynamic>? wall;
  final ReportData? reportData;

  Report({
    required this.id,
    required this.title,
    required this.notes,
    required this.createdAt,
    this.wall,
    this.reportData,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      notes: json['notes'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      wall: json['wall_id'] is Map ? json['wall_id'] : null,
      reportData: json['reportData'] != null
          ? ReportData.fromJson(json['reportData'])
          : null,
    );
  }
}

class ReportData {
  final Map<String, dynamic> engagement;
  final Map<String, dynamic> quality;
  final List<dynamic> trends;

  final List<dynamic> byDayOfWeek;
  final List<dynamic> byHourOfDay;
  final List<dynamic> recentFeedback;
  final List<dynamic> demographics;
  final List<dynamic> recentIssues;

  ReportData({
    required this.engagement,
    required this.quality,
    required this.trends,
    required this.byDayOfWeek,
    required this.byHourOfDay,
    required this.recentFeedback,
    required this.demographics,
    required this.recentIssues,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      engagement: json['engagement'] ?? {},
      quality: json['quality'] ?? {},
      trends: json['trends']?['last30Days'] ?? [],
      byDayOfWeek: json['trends']?['byDayOfWeek'] ?? [],
      byHourOfDay: json['trends']?['byHourOfDay'] ?? [],
      recentFeedback: json['recentFeedback'] ?? [],
      demographics: json['demographics'] ?? [],
      recentIssues: json['recentIssues'] ?? [],
    );
  }
}
