const baseUrl = 'http://127.0.0.1:3000';

class ApiConfig {
  // Main API base URL
  static const String apiBaseUrl = '$baseUrl';

  // Auth endpoints (using /api/user)
  static const String registerPath = '/auth/register';
  static const String loginPath = '/auth/login';
  static const String refreshPath = '/auth/refresh';
  static const String logoutPath = '/auth/logout';
}