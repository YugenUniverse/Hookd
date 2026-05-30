import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import '../models/report.dart';
import '../models/wall.dart';

class ReportService {
  final String baseUrl = ApiConfig.apiBaseUrl;
  final String token;

  ReportService({required this.token});

  Future<List<dynamic>> getWalls() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final userType = data['userType'];
      if (userType == 'PublicBody') {
        final walls = data['walls'];
        if (walls is List) return walls;
      } else {
        final facility = data['facility'];
        if (facility is Map) {
          final walls = facility['walls'];
          if (walls is List) return walls;
        }
      }
      return [];
    } else {
      throw Exception('Failed to load facility walls');
    }
  }

  Future<List<Report>> getAllSavedReports() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/saved'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Report.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load archived reports');
    }
  }

  Future<ReportData> getLiveReport(String wallId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/wall/$wallId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return ReportData.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load live data');
    }
  }

  Future<String?> _getWallName(String wallId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/walls/$wallId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return Wall.fromJson(decoded).name;
        }
        if (decoded is Map) {
          return Wall.fromJson(Map<String, dynamic>.from(decoded)).name;
        }
      }
    } catch (_) {
      // Ignore wall lookup failures so grouped report aggregation can continue.
    }

    return null;
  }

  Future<ReportData> getLiveGroupReport(List<String> wallIds) async {
    final reportDataList = await Future.wait(
      wallIds.map((wallId) => getLiveReport(wallId)),
    );
    final wallNamesById = await _fetchWallNames(wallIds);
    return _aggregateGroupedReportData(wallIds, reportDataList, wallNamesById);
  }

  Future<Map<String, String>> _fetchWallNames(List<String> wallIds) async {
    final resolvedNames = await Future.wait(
      wallIds.map((wallId) async {
        final name = await _getWallName(wallId);
        if (name == null || name.trim().isEmpty) {
          return MapEntry(wallId, '');
        }
        return MapEntry(wallId, name);
      }),
    );

    return Map.fromEntries(resolvedNames);
  }

  ReportData _aggregateGroupedReportData(
    List<String> wallIds,
    List<ReportData> reportDataList,
    Map<String, String> wallNamesById,
  ) {
    final Map<String, int> trendCounts = {};
    final Map<int, int> dayCounts = {};
    final Map<int, int> hourCounts = {};
    final Map<String, int> demographicCounts = {};
    final List<dynamic> combinedFeedback = [];
    final List<dynamic> combinedIssues = [];
    final Map<int, int> combinedDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    final List<Map<String, dynamic>> wallComparisons = List.generate(
      reportDataList.length,
      (index) {
        final wallId = wallIds[index];
        final resolvedWallName =
            wallNamesById[wallId]?.trim().isNotEmpty == true
            ? wallNamesById[wallId]!
            : reportDataList[index].wallName;

        return {
          'wallId': wallId,
          'wallName': resolvedWallName ?? 'Wall ${index + 1}',
          'engagement': reportDataList[index].engagement,
          'quality': reportDataList[index].quality,
        };
      },
    );

    for (final data in reportDataList) {
      for (final trend in data.trends) {
        final String date = trend['date'] as String;
        final int count = (trend['sessions'] as num).toInt();
        trendCounts[date] = (trendCounts[date] ?? 0) + count;
      }

      for (final trend in data.byDayOfWeek) {
        final int day = trend['day'] as int;
        final int count = (trend['count'] as num).toInt();
        dayCounts[day] = (dayCounts[day] ?? 0) + count;
      }

      for (final trend in data.byHourOfDay) {
        final int hour = trend['hour'] as int;
        final int count = (trend['count'] as num).toInt();
        hourCounts[hour] = (hourCounts[hour] ?? 0) + count;
      }

      for (final demographic in data.demographics) {
        final String bracket = demographic['bracket'] as String;
        final int count = (demographic['count'] as num).toInt();
        demographicCounts[bracket] = (demographicCounts[bracket] ?? 0) + count;
      }

      combinedFeedback.addAll(data.recentFeedback);
      combinedIssues.addAll(data.recentIssues);

      for (final item in data.quality['distribution'] ?? []) {
        final int stars = item['stars'] as int;
        final int count = (item['count'] as num).toInt();
        combinedDistribution[stars] =
            (combinedDistribution[stars] ?? 0) + count;
      }
    }

    combinedFeedback.sort((a, b) {
      final aDate =
          DateTime.tryParse((a['date'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          DateTime.tryParse((b['date'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    final limitedFeedback = combinedFeedback.take(3).toList();

    final totalSessions = reportDataList.fold<int>(0, (sum, data) {
      return sum + ((data.engagement['totalSessions'] ?? 0) as int);
    });
    final totalUniqueClimbers = reportDataList.fold<int>(0, (sum, data) {
      return sum + ((data.engagement['uniqueClimbers'] ?? 0) as int);
    });
    final totalSends = reportDataList.fold<int>(0, (sum, data) {
      return sum + ((data.engagement['totalSends'] ?? 0) as int);
    });
    final totalAttempts = reportDataList.fold<int>(0, (sum, data) {
      return sum + ((data.engagement['totalAttempts'] ?? 0) as int);
    });

    final averageRetention = reportDataList.isEmpty
        ? 0.0
        : reportDataList.fold<double>(0.0, (sum, data) {
                final value = (data.engagement['retentionRate'] ?? 0) as num;
                return sum + value.toDouble();
              }) /
              reportDataList.length;
    final averageTime = reportDataList.isEmpty
        ? 0.0
        : reportDataList.fold<double>(0.0, (sum, data) {
                final value = (data.engagement['avgTimeMins'] ?? 0) as num;
                return sum + value.toDouble();
              }) /
              reportDataList.length;

    return ReportData(
      engagement: {
        'totalSessions': totalSessions,
        'uniqueClimbers': totalUniqueClimbers,
        'retentionRate': averageRetention,
        'avgTimeMins': averageTime,
        'totalSends': totalSends,
        'totalAttempts': totalAttempts,
      },
      quality: {
        'distribution': combinedDistribution.entries
            .map((entry) => {'stars': entry.key, 'count': entry.value})
            .toList(),
      },
      trends: trendCounts.entries
          .map((entry) => {'date': entry.key, 'sessions': entry.value})
          .toList(),
      byDayOfWeek: dayCounts.entries
          .map((entry) => {'day': entry.key, 'count': entry.value})
          .toList(),
      byHourOfDay: hourCounts.entries
          .map((entry) => {'hour': entry.key, 'count': entry.value})
          .toList(),
      recentFeedback: limitedFeedback,
      demographics: demographicCounts.entries
          .map((entry) => {'bracket': entry.key, 'count': entry.value})
          .toList(),
      recentIssues: combinedIssues,
      wallComparisons: wallComparisons,
    );
  }

  Future<Report> saveReportSnapshot(
    String wallId,
    String title,
    String notes,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reports/wall/$wallId/save'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'title': title, 'notes': notes}),
    );

    if (response.statusCode == 201) {
      final responseData = json.decode(response.body);
      return Report.fromJson(responseData['report'] ?? responseData);
    } else {
      throw Exception('Failed to freeze report snapshot');
    }
  }

  Future<Report> saveGroupReport(
    List<String> wallIds,
    String title,
    String notes,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reports/walls/save'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'title': title, 'notes': notes, 'wallIds': wallIds}),
    );

    if (response.statusCode == 201) {
      final responseData = json.decode(response.body);
      return Report.fromJson(responseData['report'] ?? responseData);
    } else {
      throw Exception('Failed to freeze grouped report snapshot');
    }
  }

  Future<Report> getReportDetails(String reportId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/saved/$reportId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return Report.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load report details');
    }
  }

  Future<String> exportReportCsv(
    String reportId, {
    List<String>? sections,
  }) async {
    final uri = Uri.parse('$baseUrl/reports/saved/$reportId/export').replace(
      queryParameters: sections == null || sections.isEmpty
          ? null
          : {'sections': sections.join(',')},
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'text/csv'},
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to export CSV report');
    }
  }
}
