import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get apiBaseUrl {
    final url = dotenv.env['BACKEND_URL'] ?? 'localhost:3000';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return 'http://$url';
  }

  // Auth endpoints (using /api/user)
  static const String registerPath = '/auth/register';
  static const String loginPath = '/auth/login';
  static const String refreshPath = '/auth/refresh';
  static const String logoutPath = '/auth/logout';
  static const String googlePath = '/auth/google';
}
