import 'package:dio/dio.dart';
import 'dart:async';

import '../models/user.dart';
import '../models/climbing_session.dart';
import '../models/poi.dart';
import '../models/review.dart';
import '../models/wall.dart';
import '../models/issue.dart';
import '../models/badge.dart';
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

  Future<User> fetchCurrentUserProfile({String? bearerToken}) async {
    final options = Options(headers: {});
    final token = (bearerToken != null && bearerToken.isNotEmpty)
        ? bearerToken
        : AuthService().jwt;
    if (token == null || token.isEmpty || !AuthService().isAuthenticated) {
      // Fail fast so callers can react (show login) instead of receiving a DioException
      throw StateError('Not authenticated');
    }
    options.headers!['Authorization'] = 'Bearer $token';
    final response = await _dio.get('/users/me', options: options);
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return User.fromJson(data);
    }

    throw StateError(
      'Unexpected /users/me response shape: ${data.runtimeType}',
    );
  }

  Future<User> fetchUserProfile(String userId, {String? bearerToken}) async {
    return fetchCurrentUserProfile(bearerToken: bearerToken);
  }

  Future<List<ClimbingSession>> fetchCurrentUserSessions({
    String? bearerToken,
  }) async {
    final options = Options(headers: {});
    if (bearerToken != null && bearerToken.isNotEmpty) {
      options.headers!['Authorization'] = 'Bearer $bearerToken';
    }

    final response = await _dio.get('/sessions', options: options);
    final data = response.data;

    final sessionsRaw = data is Map ? data['sessions'] : data;
    if (sessionsRaw is! List) {
      throw StateError(
        'Unexpected /sessions response shape: ${data.runtimeType}',
      );
    }

    return sessionsRaw
        .whereType<Map>()
        .map(
          (session) =>
              ClimbingSession.fromJson(Map<String, dynamic>.from(session)),
        )
        .toList();
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

  Future<List<Badge>> getSystemBadges() async {
    try {
      final response = await _dio.get('/badges', queryParameters: {'type': 'system'});
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => Badge.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('Error fetching system badges: $e');
      return [];
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

  Future<List<Review>> getWallReviews(String wallId) async {
    try {
      final response = await _dio.get('/reviews/wall/$wallId');
      final data = response.data;

      final reviewsRaw = data is Map ? data['reviews'] : null;
      if (reviewsRaw is! List) {
        return [];
      }

      return reviewsRaw
          .whereType<Map>()
          .map((review) => Review.fromJson(Map<String, dynamic>.from(review)))
          .toList();
    } catch (e) {
      print('Error fetching wall reviews: $e');
      return [];
    }
  }

  Future<List<Poi>> getAllPois() async {
    try {
      final response = await _dio.get('/pois');
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => Poi.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('Error fetching all POIs: $e');
      return [];
    }
  }

  Future<List<Poi>> getNearbyPois(
    double lng,
    double lat, {
    double radius = 30000,
  }) async {
    try {
      final response = await _dio.get(
        '/pois/nearby',
        queryParameters: {'lng': lng, 'lat': lat, 'radius': radius.toInt()},
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => Poi.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('Error fetching nearby POIs: $e');
      return [];
    }
  }

  Future<List<Poi>> searchPois(
    String query, {
    String type = 'all',
    String? difficulty,
  }) async {
    try {
      final queryParameters = <String, dynamic>{'q': query, 'type': type};
      if (difficulty != null && difficulty.isNotEmpty) {
        queryParameters['difficulty'] = difficulty;
      }
      final response = await _dio.get(
        '/pois/search',
        queryParameters: queryParameters,
      );
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => Poi.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('Error searching POIs: $e');
      return [];
    }
  }

  Future<Wall?> getWallById(String wallId) async {
    try {
      final response = await _dio.get('/walls/$wallId');
      final data = response.data;
      if (data is Map || data is Map<String, dynamic>) {
        return Wall.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      print('Error fetching wall by id: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createSession({
    required String wallId,
    required DateTime date,
    required int time,
    int? rating,
    String? reviewBody,
    bool isPrivate = false,
  }) async {
    final payload = <String, dynamic>{
      'wall_id': wallId,
      'date': _formatDate(date),
      'time': time,
      'is_private': isPrivate,
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

  // Issue endpoints
  Future<void> createIssue({
    required String wallId,
    required String body,
  }) async {
    final payload = {'wall_id': wallId, 'body': body};
    final response = await _dio.post('/issues', data: payload);
    if (response.statusCode != 201) {
      throw Exception('Failed to create issue: ${response.statusCode}');
    }
  }

  Future<List<Issue>> fetchIssuesForWall(String wallId) async {
    final response = await _dio.get('/issues/walls/$wallId');
    final data = response.data;
    final issuesList = <Issue>[];
    if (data is Map && data['issues'] is List) {
      for (final item in data['issues']) {
        if (item is Map<String, dynamic>) {
          issuesList.add(Issue.fromJson(item));
        } else if (item is Map) {
          issuesList.add(Issue.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return issuesList;
  }

  Future<List<Issue>> fetchIssuesForUser() async {
    final response = await _dio.get('/issues/my-issues');
    final data = response.data;
    final issuesList = <Issue>[];
    if (data is Map && data['issues'] is List) {
      for (final item in data['issues']) {
        if (item is Map<String, dynamic>) {
          issuesList.add(Issue.fromJson(item));
        } else if (item is Map) {
          issuesList.add(Issue.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return issuesList;
  }

  Future<void> deleteIssue(String issueId) async {
    final response = await _dio.delete('/issues/$issueId');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete issue: ${response.statusCode}');
    }
  }

  Future<void> updateIssueStatus(String issueId, String status) async {
    await _dio.put('/issues/$issueId/status', data: {'status': status});
  }

  Future<List<Map<String, dynamic>>> searchFacilities(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final resp = await Dio(
        BaseOptions(baseUrl: ApiConfig.apiBaseUrl),
      ).get('/facilities/search', queryParameters: {'q': query.trim()});
      final data = resp.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> claimFacility(String facilityId) async {
    try {
      await _dio.post('/facilities/$facilityId/claim');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateFacility(
    String facilityId, {
    required String name,
    required String description,
    required Map<String, dynamic> location,
  }) async {
    try {
      await _dio.put(
        '/facilities/$facilityId',
        data: {'name': name, 'description': description, 'location': location},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unpairFacility(String facilityId) async {
    try {
      await _dio.post('/facilities/$facilityId/unpair');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createWall({
    required String name,
    required String description,
    required String difficulty,
    double? longitude,
    double? latitude,
    String? address,
  }) async {
    try {
      await _dio.post(
        '/walls',
        data: {
          'name': name,
          'description': description,
          'difficulty': difficulty,
          if (longitude != null && latitude != null)
            'location': {
              'type': 'Point',
              'coordinates': [longitude, latitude],
              if (address != null && address.isNotEmpty) 'address': address,
            },
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteWall(String wallId) async {
    try {
      await _dio.delete('/walls/$wallId');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateWall(
    String wallId, {
    required String name,
    required String description,
    required String difficulty,
  }) async {
    try {
      await _dio.put(
        '/walls/$wallId',
        data: {
          'name': name,
          'description': description,
          'difficulty': difficulty,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
