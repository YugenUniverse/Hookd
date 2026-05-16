import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import '../models/report.dart';

class ReportService {
  final String baseUrl = ApiConfig.apiBaseUrl;
  final String token;

  ReportService({required this.token});

  Future<List<dynamic>> getFacilityWalls() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final facility = data['facility'];
      if (facility is Map) {
        final walls = facility['walls'];
        if (walls is List) return walls;
      }
      return [];
    } else {
      throw Exception('Failed to load facility walls');
    }
  }

  Future<List<Report>> getAllSavedReports() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/reports/saved',
      ), // Adjust to match your backend history route
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
}
