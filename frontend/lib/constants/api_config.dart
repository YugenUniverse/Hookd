import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get apiBaseUrl =>
      'http://${dotenv.env['BACKEND_URL'] ?? 'localhost:3000'}';

  // Auth endpoints (using /api/user)
  static const String registerPath = '/auth/register';
  static const String loginPath = '/auth/login';
  static const String refreshPath = '/auth/refresh';
  static const String logoutPath = '/auth/logout';
  static const String googlePath = '/auth/google';
}
