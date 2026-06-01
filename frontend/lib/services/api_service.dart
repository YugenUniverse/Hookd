import 'package:dio/dio.dart';
import 'dart:async';

import '../models/user.dart';
import '../models/climbing_session.dart';
import '../models/poi.dart';
import '../models/review.dart';
import '../models/wall.dart';
import '../models/issue.dart';
import '../models/event.dart';
import '../models/app_notification.dart';
import '../models/badge.dart';
import '../models/group.dart';
import '../models/conversation.dart';
import '../models/message.dart';
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

  /// Fetches the current user's profile and stores avatar + username in
  /// [AuthService] so the navbar can display the PFP immediately.
  Future<void> loadAndCacheAvatar() async {
    try {
      final user = await fetchCurrentUserProfile();
      AuthService().setCurrentUserProfile(
        avatar: user.profilePictureUrl ?? '',
        username: user.username,
      );
    } catch (_) {}
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
    final response = await _dio.get('/users/$userId');
    final data = response.data;
    if (data is! Map) throw StateError('Unexpected /users/$userId response');
    final map = Map<String, dynamic>.from(data as Map);
    // The public endpoint nests bio/description under 'profile' — flatten it
    if (map['profile'] is Map) {
      (map['profile'] as Map<dynamic, dynamic>).forEach((k, v) => map.putIfAbsent(k.toString(), () => v));
    }
    return User.fromJson(map);
  }

  Future<User> updateCurrentUserProfile(Map<String, dynamic> updates) async {
    final response = await _dio.patch('/users/me', data: updates);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return User.fromJson(data);
    }
    throw StateError('Unexpected /users/me PATCH response: ${data.runtimeType}');
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

  Future<List<ClimbingSession>> getPublicSessions(String userId, {int limit = 20}) async {
    try {
      final response = await _dio.get(
        '/sessions/user/$userId',
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      if (data is! Map) return [];
      final list = (data['sessions'] as List<dynamic>?) ?? [];
      return list
          .whereType<Map>()
          .map((j) => ClimbingSession.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (_) {
      return [];
    }
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

  Future<List<Badge>> getBadgesForEvent(String eventId) async {
    try {
      final response = await _dio.get('/badges', queryParameters: {
        'type': 'event',
        'eventId': eventId,
      });
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => Badge.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('Error fetching event badges: $e');
      return [];
    }
  }

  Future<Badge> createEventBadge({
    required String name,
    required String description,
    required int score,
    required int level,
    required String eventId,
    required WinningCondition winningCondition,
  }) async {
    final payload = {
      'name': name,
      'description': description,
      'score': score,
      'level': level,
      'type': 'event',
      'eventId': eventId,
      'winningCondition': winningCondition.toJson(),
    };
    final response = await _dio.post('/badges', data: payload);
    return Badge.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<Badge> updateEventBadge(
    String badgeId, {
    required String name,
    required String description,
    required int score,
    required int level,
    required WinningCondition winningCondition,
  }) async {
    final payload = {
      'name': name,
      'description': description,
      'score': score,
      'level': level,
      'winningCondition': winningCondition.toJson(),
    };
    final response = await _dio.put('/badges/$badgeId', data: payload);
    return Badge.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> deleteBadge(String badgeId) async {
    await _dio.delete('/badges/$badgeId');
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
    String severity = 'MEDIUM',
    String description = '',
    String location = '',
  }) async {
    final payload = {
      'wall_id': wallId,
      'body': body,
      'severity': severity,
    };
    if (description.isNotEmpty) {
      payload['description'] = description;
    }
    if (location.isNotEmpty) {
      payload['location'] = location;
    }
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

  Future<List<Issue>> fetchPublicBodyIssuesDashboard({
    List<String>? statuses,
    List<String>? severities,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (statuses != null && statuses.isNotEmpty) {
        queryParams['status'] = statuses;
      }
      if (severities != null && severities.isNotEmpty) {
        queryParams['severity'] = severities;
      }

      final response = await _dio.get(
        '/issues/public-body/dashboard',
        queryParameters: queryParams,
      );
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
    } catch (e) {
      print('Error fetching public body issues: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchPublicBodyIssueSummary() async {
    try {
      final response = await _dio.get('/issues/public-body/dashboard/summary');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
    } catch (e) {
      print('Error fetching issue summary: $e');
      return {};
    }
  }

  // Admin Endpoints
  Future<List<User>> getPendingApprovals() async {
    try {
      final response = await _dio.get('/admin/approvals/pending');
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching pending approvals: $e');
      return [];
    }
  }

  Future<void> approveAccount(String userId) async {
    final response = await _dio.put('/admin/approvals/$userId/approve');
    if (response.statusCode != 200) {
      throw Exception('Failed to approve account');
    }
  }

  Future<void> rejectAccount(String userId) async {
    final response = await _dio.put('/admin/approvals/$userId/reject');
    if (response.statusCode != 200) {
      throw Exception('Failed to reject account');
    }
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count');
      final count = response.data is Map ? response.data['count'] : 0;
      return (count as num?)?.toInt() ?? 0;
    } catch (e) {
      print('Error fetching unread count: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> searchFacilities(String query) async {
    if (query.trim().length < 2) return [];
    final resp = await _dio.get(
      '/facilities/search',
      queryParameters: {'q': query.trim()},
    );
    final data = resp.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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

  // Event endpoints

  Future<Event> createEvent({
    required String title,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    List<String> walls = const [],
    String? groupId,
    String? facilityId,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'startDate': startDate.toIso8601String(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      'walls': walls,
      if (facilityId != null) 'facilityId': facilityId,
    };
    final url = groupId != null ? '/groups/$groupId/events' : '/events';
    final response = await _dio.post(url, data: payload);
    final data = response.data;
    if (data is Map<String, dynamic> && data['event'] is Map<String, dynamic>) {
      return Event.fromJson(data['event'] as Map<String, dynamic>);
    }
    throw StateError('Unexpected /events response');
  }

  Future<List<Event>> getEventsForFacility(String facilityId) async {
    final response = await _dio.get('/events', queryParameters: {'facilityId': facilityId});
    final data = response.data;
    final list = data is Map ? data['events'] : null;
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((m) => Event.fromJson(m))
        .toList();
  }

  Future<List<Event>> getEventsForGroup(String groupId) async {
    final response = await _dio.get('/groups/$groupId/events');
    final data = response.data;
    final list = data is Map ? data['events'] : null;
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((m) => Event.fromJson(m))
        .toList();
  }

  Future<List<Event>> getActiveEvents() async {
    final response = await _dio.get('/events/active');
    final data = response.data;
    final list = data is Map ? data['events'] : null;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Event.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Event> updateEvent(
    String eventId, {
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? walls,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (startDate != null) body['startDate'] = startDate.toIso8601String();
    if (endDate != null) body['endDate'] = endDate.toIso8601String();
    if (walls != null) body['walls'] = walls;
    final response = await _dio.patch('/events/$eventId', data: body);
    return Event.fromJson(Map<String, dynamic>.from(response.data['event']));
  }

  Future<void> deleteEvent(String eventId) async {
    await _dio.delete('/events/$eventId');
  }

  Future<Map<String, dynamic>> closeEvent(String eventId) async {
    final response = await _dio.post('/events/$eventId/close');
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getEventLeaderboard(String eventId) async {
    final response = await _dio.get('/events/$eventId/leaderboard');
    final List<dynamic> data = response.data['leaderboard'];
    return data.cast<Map<String, dynamic>>();
  }

  // Follow endpoints

  Future<List<Map<String, dynamic>>> getMyFollowers() async {
    try {
      final response = await _dio.get('/follows/me/followers');
      final data = response.data;
      final list = data is Map ? data['followers'] : null;
      if (list is! List) return [];
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    try {
      final response = await _dio.get('/follows/$userId/followers');
      final data = response.data;
      final list = data is Map ? data['followers'] : null;
      if (list is! List) return [];
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFollowingUsers(String userId) async {
    try {
      final response = await _dio.get('/follows/$userId/following');
      final data = response.data;
      final list = data is Map ? data['following'] : null;
      if (list is! List) return [];
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> followUser(String userId) async {
    await _dio.post('/follows/$userId');
  }

  Future<void> unfollowUser(String userId) async {
    await _dio.delete('/follows/$userId');
  }

  Future<bool> checkFollowing(String userId) async {
    try {
      final response = await _dio.get('/follows/check/$userId');
      return response.data['following'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getFollowing() async {
    try {
      final response = await _dio.get('/follows/me');
      final data = response.data;
      final list = data is Map ? data['following'] : null;
      if (list is! List) return [];
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // Notification endpoints

  Future<List<AppNotification>> getNotifications() async {
    final response = await _dio.get('/notifications');
    final data = response.data;
    final list = data is Map ? data['notifications'] : null;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _dio.patch('/notifications/$notificationId/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.patch('/notifications/read-all');
  }

  Future<void> registerFcmToken(String token) async {
    await _dio.post('/users/fcm-token', data: {'token': token});
  }

  // Group endpoints

  Future<Group> createGroup({
    required String name,
    String? description,
    String visibility = 'private',
  }) async {
    final response = await _dio.post('/groups', data: {
      'name': name,
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      'visibility': visibility,
    });
    return Group.fromJson(Map<String, dynamic>.from(response.data['group']));
  }

  Future<List<Group>> getMyGroups() async {
    final response = await _dio.get('/groups/mine');
    final list = response.data is Map ? response.data['groups'] : null;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Group.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Group> getGroupById(String groupId) async {
    final response = await _dio.get('/groups/$groupId');
    return Group.fromJson(Map<String, dynamic>.from(response.data['group']));
  }

  Future<Group> updateGroup(String groupId, {String? name, String? description}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    final response = await _dio.patch('/groups/$groupId', data: body);
    return Group.fromJson(Map<String, dynamic>.from(response.data['group']));
  }

  Future<void> deleteGroup(String groupId) async {
    await _dio.delete('/groups/$groupId');
  }

  Future<void> inviteToGroup(String groupId, String username) async {
    await _dio.post('/groups/$groupId/invites', data: {'username': username});
  }

  Future<List<GroupInvitation>> getPendingGroupInvites() async {
    final response = await _dio.get('/groups/invites/pending');
    final list = response.data is Map ? response.data['invitations'] : null;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => GroupInvitation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Group> acceptGroupInvite(String inviteId) async {
    final response = await _dio.patch('/groups/invites/$inviteId/accept');
    return Group.fromJson(Map<String, dynamic>.from(response.data['group']));
  }

  Future<void> declineGroupInvite(String inviteId) async {
    await _dio.patch('/groups/invites/$inviteId/decline');
  }

  Future<void> leaveOrRemoveFromGroup(String groupId, String userId) async {
    await _dio.delete('/groups/$groupId/members/$userId');
  }

  Future<List<Group>> discoverGroups({String? search}) async {
    final response = await _dio.get(
      '/groups/discover',
      queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
    );
    final list = response.data is Map ? response.data['groups'] : null;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Group.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Group> joinGroup(String groupId) async {
    final response = await _dio.post('/groups/$groupId/join');
    return Group.fromJson(Map<String, dynamic>.from(response.data['group']));
  }

  Future<List<PlannedClimb>> getPlannedClimbs(String groupId) async {
    final response = await _dio.get('/groups/$groupId/climbs');
    final list = response.data['climbs'] as List;
    return list.map((e) => PlannedClimb.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<PlannedClimb> createPlannedClimb(
    String groupId, {
    required DateTime date,
    String? venueId,
    String? venueType,
    String? notes,
  }) async {
    final response = await _dio.post('/groups/$groupId/climbs', data: {
      'date': date.toUtc().toIso8601String(),
      if (venueId != null) 'venueId': venueId,
      if (venueType != null) 'venueType': venueType,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return PlannedClimb.fromJson(Map<String, dynamic>.from(response.data['climb']));
  }

  Future<void> deletePlannedClimb(String groupId, String climbId) async {
    await _dio.delete('/groups/$groupId/climbs/$climbId');
  }

  Future<PlannedClimb> rsvpPlannedClimb(String groupId, String climbId, String status) async {
    final response = await _dio.patch(
      '/groups/$groupId/climbs/$climbId/rsvp',
      data: {'status': status},
    );
    return PlannedClimb.fromJson(Map<String, dynamic>.from(response.data['climb']));
  }

  // Conversation / chat endpoints

  Future<List<Map<String, dynamic>>> searchClimbers(String query) async {
    final response = await _dio.get('/climbers/search', queryParameters: {'q': query});
    final list = response.data is Map ? response.data['users'] : null;
    if (list is! List) return [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Conversation> getGroupConversation(String groupId) async {
    final response = await _dio.get('/conversations/group/$groupId');
    return Conversation.fromJson(
        Map<String, dynamic>.from(response.data['conversation']));
  }

  Future<List<Conversation>> getConversations() async {
    final response = await _dio.get('/conversations');
    final list = response.data is Map ? response.data['conversations'] : null;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Conversation> getOrCreateDm(String targetUserId) async {
    final response = await _dio.post('/conversations/dm/$targetUserId');
    return Conversation.fromJson(
        Map<String, dynamic>.from(response.data['conversation']));
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    String? before,
    int limit = 30,
  }) async {
    final response = await _dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {
        'limit': limit,
        if (before != null) 'before': before,
      },
    );
    final list = response.data is Map ? response.data['messages'] : null;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ChatMessage> sendMessageRest(
      String conversationId, String content) async {
    final response = await _dio.post(
      '/conversations/$conversationId/messages',
      data: {'content': content},
    );
    return ChatMessage.fromJson(
        Map<String, dynamic>.from(response.data['message']));
  }

  Future<void> markConversationRead(String conversationId) async {
    await _dio.patch('/conversations/$conversationId/read');
  }

  Future<void> updateDmPrivacy(String allowDmsFrom) async {
    await _dio.patch('/climbers/me', data: {'allowDmsFrom': allowDmsFrom});
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
