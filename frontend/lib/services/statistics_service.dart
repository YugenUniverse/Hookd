import 'package:dio/dio.dart';

import '../models/statistics_filter.dart';

/// Service for calling statistics API endpoints
class StatisticsService {
  final Dio _dio;
  final String _baseUrl;

  StatisticsService({required Dio dio, required String baseUrl})
    : _dio = dio,
      _baseUrl = baseUrl;

  /// Fetch statistics filtered by geographic area and time range
  /// Returns aggregated stats including engagement, quality, trends, demographics
  Future<Map<String, dynamic>> getStatisticsByAreaAndTime(
    StatisticsFilter filter,
  ) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/reports/stats/area-time',
        queryParameters: filter.toQueryParams(),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch statistics: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('API error: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching statistics: $e');
    }
  }
}
