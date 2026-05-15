import 'package:dio/dio.dart';
import 'dart:async';

import '../models/user.dart';
import '../models/wall.dart';
import '../models/issue_report.dart';
import '../constants/api_config.dart';
import 'auth_service.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.apiBaseUrl));

  // Single shared future while a refresh is in-flight
  Future<bool>? _refreshInProgress;

  ApiService() {
    // Add interceptor to handle 401 and refresh token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = AuthService().jwt;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;

          // Only attempt refresh on 401 and if we haven't retried this request yet
          if (status == 401 && !alreadyRetried) {
            print('Got 401 error, attempting token refresh...');
            try {
              // If another refresh is in progress, wait for it instead of starting a new one
              _refreshInProgress ??= AuthService().refresh();
              final refreshed = await _refreshInProgress!;
              // clear the shared future after it completes (success or failure)
              _refreshInProgress = null;

              if (refreshed) {
                print('Token refresh succeeded, retrying original request');
                // mark request as retried so we don't loop
                error.requestOptions.extra['retried'] = true;
                // update auth header with new token
                final token = AuthService().jwt;
                if (token != null) {
                  error.requestOptions.headers['Authorization'] =
                      'Bearer $token';
                }
                // Retry the original request and resolve with its response
                final opts = Options(
                  method: error.requestOptions.method,
                  headers: error.requestOptions.headers,
                );
                final response = await _dio.request(
                  error.requestOptions.path,
                  data: error.requestOptions.data,
                  queryParameters: error.requestOptions.queryParameters,
                  options: opts,
                );
                return handler.resolve(response);
              } else {
                // refresh failed -> logout and forward original error
                print('Token refresh failed, logging out');
                await AuthService().logout();
                return handler.next(error);
              }
            } catch (e) {
              print('Error during token refresh: $e');
              _refreshInProgress = null;
              // something went wrong while refreshing -> forward original error
              return handler.next(error);
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  Future<User> fetchUserProfile(String userId, {String? bearerToken}) async {
    final options = Options(headers: {});
    if (bearerToken != null && bearerToken.isNotEmpty) {
      options.headers!['Authorization'] = 'Bearer $bearerToken';
    }
    final response = await _dio.get('/me', options: options);
    print(bearerToken);
    print(response.data);
    return User.fromJson(response.data);
  }

  Future<Map<String, dynamic>> checkServerHealth() async {
    try {
      final response = await _dio
          .get('/status')
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Server request timed out');
            },
          );
      return {
        'status': 'online',
        'statusCode': response.statusCode,
        'message': 'Server is responding',
      };
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return {
          'status': 'timeout',
          'statusCode': null,
          'message': 'Connection timeout',
        };
      } else if (e.type == DioExceptionType.connectionError) {
        return {
          'status': 'offline',
          'statusCode': null,
          'message': 'Cannot connect to server',
        };
      } else if (e.response != null) {
        return {
          'status': 'error',
          'statusCode': e.response!.statusCode,
          'message': 'Server error: ${e.response!.statusCode}',
        };
      }
      return {
        'status': 'offline',
        'statusCode': null,
        'message': 'Server unreachable',
      };
    } on TimeoutException {
      return {
        'status': 'timeout',
        'statusCode': null,
        'message': 'Connection timeout',
      };
    } catch (e) {
      return {
        'status': 'error',
        'statusCode': null,
        'message': 'Unknown error: ${e.toString()}',
      };
    }
  }

  // Wall endpoints
  Future<List<Wall>> getAllWalls() async {
    try {
      final response = await _dio.get('/walls');
      final data = response.data;
      print('getAllWalls response type: ${data.runtimeType}, data: $data');

      List<Wall> walls = [];
      if (data is List) {
        print('Response is a List with ${data.length} items');
        walls = data
            .map((wall) => Wall.fromJson(wall as Map<String, dynamic>))
            .toList();
      } else if (data is Map && data.containsKey('walls')) {
        final wallsList = data['walls'] as List;
        print(
          'Response is a Map with walls key, containing ${wallsList.length} items',
        );
        walls = wallsList
            .map((wall) => Wall.fromJson(wall as Map<String, dynamic>))
            .toList();
      }
      print('Parsed ${walls.length} walls');
      for (var wall in walls) {
        print('Wall: ${wall.name} at (${wall.latitude}, ${wall.longitude})');
      }
      return walls;
    } catch (e) {
      print('Error fetching all walls: $e');
      return [];
    }
  }

  Future<List<Wall>> getNearbyWalls(
    double lng,
    double lat, {
    double radius = 30000,
  }) async {
    try {
      print('Fetching nearby walls for lng: $lng, lat: $lat, radius: $radius');
      final response = await _dio.get(
        '/walls/nearby',
        queryParameters: {'lng': lng, 'lat': lat, 'radius': radius.toInt()},
      );
      final data = response.data;
      print('getNearbyWalls response type: ${data.runtimeType}, data: $data');

      List<Wall> walls = [];
      if (data is List) {
        print('Response is a List with ${data.length} items');
        walls = data
            .map((wall) => Wall.fromJson(wall as Map<String, dynamic>))
            .toList();
      } else if (data is Map && data.containsKey('walls')) {
        final wallsList = data['walls'] as List;
        print(
          'Response is a Map with walls key, containing ${wallsList.length} items',
        );
        walls = wallsList
            .map((wall) => Wall.fromJson(wall as Map<String, dynamic>))
            .toList();
      }
      print('Parsed ${walls.length} nearby walls');
      for (var wall in walls) {
        print('Wall: ${wall.name} at (${wall.latitude}, ${wall.longitude})');
      }
      return walls;
    } catch (e) {
      print('Error fetching nearby walls: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createSession({
    required String wallId,
    required DateTime date,
    required int time,
    int? rating,
    String? reviewBody,
  }) async {
    final payload = <String, dynamic>{
      'wall_id': wallId,
      'date': _formatDate(date),
      'time': time,
    };

    if (rating != null) {
      payload['review'] = {
        'rating': rating,
        if (reviewBody != null && reviewBody.trim().isNotEmpty)
          'body': reviewBody.trim(),
      };
    }

    final response = await _dio.post('/sessions', data: payload);
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Unexpected response while creating session');
  }

  // Report endpoints
  Future<void> createIssueReport({
    required String wallId,
    required String body,
  }) async {
    final payload = {'wall_id': wallId, 'body': body};
    final response = await _dio.post('/reports', data: payload);
    if (response.statusCode != 201) {
      throw Exception('Failed to create report: ${response.statusCode}');
    }
  }

  Future<List<IssueReport>> fetchReportsForWall(String wallId) async {
    final response = await _dio.get('/reports/walls/$wallId');
    final data = response.data;
    final reportsList = <IssueReport>[];
    if (data is Map && data['reports'] is List) {
      for (final item in data['reports']) {
        if (item is Map<String, dynamic>) {
          reportsList.add(IssueReport.fromJson(item));
        } else if (item is Map) {
          reportsList.add(
            IssueReport.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return reportsList;
  }

  Future<List<IssueReport>> fetchReportsForUser() async {
    final response = await _dio.get('/reports/my-reports');
    final data = response.data;
    final reportsList = <IssueReport>[];
    if (data is Map && data['reports'] is List) {
      for (final item in data['reports']) {
        if (item is Map<String, dynamic>) {
          reportsList.add(IssueReport.fromJson(item));
        } else if (item is Map) {
          reportsList.add(
            IssueReport.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return reportsList;
  }

  Future<void> deleteReport(String reportId) async {
    final response = await _dio.delete('/reports/$reportId');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete report: ${response.statusCode}');
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
