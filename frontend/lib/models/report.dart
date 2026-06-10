class Report {
  final String id;
  final String title;
  final String notes;
  final DateTime createdAt;
  final Map<String, dynamic>? wall;
  final List<Map<String, dynamic>>? walls;
  final ReportData? reportData;

  Report({
    required this.id,
    required this.title,
    required this.notes,
    required this.createdAt,
    this.wall,
    this.walls,
    this.reportData,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['createdAt'];
    final parsedCreatedAt = createdAtValue is String
        ? DateTime.tryParse(createdAtValue) ??
              DateTime.fromMillisecondsSinceEpoch(0)
        : createdAtValue is int
        ? DateTime.fromMillisecondsSinceEpoch(createdAtValue)
        : DateTime.fromMillisecondsSinceEpoch(0);

    final wallList = (json['wall_ids'] ?? json['walls'] ?? []) as List;

    return Report(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      notes: json['notes'] ?? '',
      createdAt: parsedCreatedAt,
      wall: json['wall_id'] is Map
          ? Map<String, dynamic>.from(json['wall_id'])
          : null,
      walls: wallList
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(),
      reportData: json['reportData'] != null
          ? ReportData.fromJson(json['reportData'])
          : null,
    );
  }
}

class ReportData {
  final String? wallId;
  final String? wallName;
  final Map<String, dynamic> engagement;
  final Map<String, dynamic> quality;
  final List<dynamic> trends;

  final List<dynamic> byDayOfWeek;
  final List<dynamic> byHourOfDay;
  final List<dynamic> recentFeedback;
  final List<dynamic> demographics;
  final List<dynamic> recentIssues;
  final List<Map<String, dynamic>> wallComparisons;

  ReportData({
    this.wallId,
    this.wallName,
    required this.engagement,
    required this.quality,
    required this.trends,
    required this.byDayOfWeek,
    required this.byHourOfDay,
    required this.recentFeedback,
    required this.demographics,
    required this.recentIssues,
    required this.wallComparisons,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    final aggregatedEngagement =
        json['aggregatedEngagement'] ?? json['engagement'] ?? {};
    final aggregatedQuality =
        json['aggregatedQuality'] ?? json['quality'] ?? {};
    final aggregatedTrends = json['aggregatedTrends'] ?? json['trends'] ?? {};

    return ReportData(
      wallId: json['wallId']?.toString(),
      wallName: json['wallName']?.toString(),
      engagement: aggregatedEngagement,
      quality: aggregatedQuality,
      trends:
          aggregatedTrends['last30Days'] ?? aggregatedTrends['trends'] ?? [],
      byDayOfWeek: aggregatedTrends['byDayOfWeek'] ?? [],
      byHourOfDay: aggregatedTrends['byHourOfDay'] ?? [],
      recentFeedback:
          json['aggregatedFeedback'] ?? json['recentFeedback'] ?? [],
      demographics:
          json['aggregatedDemographics'] ?? json['demographics'] ?? [],
      recentIssues: json['aggregatedIssues'] ?? json['recentIssues'] ?? [],
      wallComparisons: (json['wallComparisons'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }
}
