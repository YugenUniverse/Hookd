import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> loadNotifications({int limit = 50, int skip = 0}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await _apiService.getNotifications();
      _updateUnreadCount();
    } catch (e) {
      print('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _apiService.getUnreadNotificationCount();
    } catch (e) {
      print('Error refreshing unread count: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiService.markNotificationRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        _notifications[index] = AppNotification(
          id: _notifications[index].id,
          type: _notifications[index].type,
          payload: _notifications[index].payload,
          read: true,
          createdAt: _notifications[index].createdAt,
        );
        _updateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.markAllNotificationsRead();
      _notifications = _notifications
          .map((n) => AppNotification(
                id: n.id,
                type: n.type,
                payload: n.payload,
                read: true,
                createdAt: n.createdAt,
              ))
          .toList();
      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      // Note: API doesn't have delete endpoint yet, just remove from list
      _notifications.removeWhere((n) => n.id == notificationId);
      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.read).length;
  }
}
