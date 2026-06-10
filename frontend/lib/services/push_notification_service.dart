import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/firebase_env.dart';
import '../constants/nav_key.dart';
import '../pages/notifications_page.dart';
import '../pages/social_page.dart';
import '../providers/notification_provider.dart';
import 'api_service.dart';
import 'auth_service.dart';

// Must be a top-level function — required by FCM for background message handling.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Notifications with a `notification` payload are auto-displayed by FCM on
  // Android/iOS. Nothing extra needed here for basic display.
}

class PushNotificationService {
  static final PushNotificationService _i = PushNotificationService._internal();
  factory PushNotificationService() => _i;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final _foregroundController = StreamController<RemoteMessage>.broadcast();

  /// Emits every message received while the app is in the foreground.
  /// Consumers (e.g. home_page) can subscribe to refresh unread counts.
  Stream<RemoteMessage> get onForegroundMessage => _foregroundController.stream;

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Token registration on auth changes
    AuthService().addListener(_onAuthChanged);
    await _getAndRegisterToken();

    // Keep token fresh if FCM rotates it
    _messaging.onTokenRefresh.listen((token) {
      if (AuthService().isAuthenticated) {
        ApiService().registerFcmToken(token).catchError((_) {});
      }
    });

    // Foreground messages — show SnackBar and notify stream subscribers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background → user tapped the notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Cold start — app launched by tapping a notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial);
  }

  void _onAuthChanged() {
    if (AuthService().isAuthenticated) {
      _getAndRegisterToken().catchError((_) {});
    }
  }

  Future<void> _getAndRegisterToken() async {
    if (!AuthService().isAuthenticated) return;
    try {
      final token = await _messaging.getToken(
        vapidKey: kIsWeb && FirebaseEnv.vapidKey.isNotEmpty ? FirebaseEnv.vapidKey : null,
      );
      if (token != null) {
        await ApiService().registerFcmToken(token);
      }
    } catch (e) {
      debugPrint('PushNotificationService: token registration failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _foregroundController.add(message);

    final isChat = message.data['type'] == 'new_message';

    // Only refresh the notification badge for non-chat pushes
    if (!isChat) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        try {
          context.read<NotificationProvider>().refreshUnreadCount();
        } catch (_) {}
      }
    }

    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? '';
    final body = notification.body ?? '';
    final onView = isChat ? _openSocialPage : _openNotificationsPage;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    messenger?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        action: SnackBarAction(label: 'View', onPressed: onView),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (message.data['type'] == 'new_message') {
      _openSocialPage();
    } else {
      _openNotificationsPage();
    }
  }

  void _openNotificationsPage() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  void _openSocialPage() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const SocialPage()),
    );
  }

  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    _foregroundController.close();
  }
}
