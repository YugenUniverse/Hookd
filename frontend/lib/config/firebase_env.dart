import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseEnv {
  static String get projectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get messagingSenderId =>
    dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get storageBucket => dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  static String get webApiKey => dotenv.env['FIREBASE_WEB_API_KEY'] ?? '';
  static String get webAppId => dotenv.env['FIREBASE_WEB_APP_ID'] ?? '';
  static String get webAuthDomain => dotenv.env['FIREBASE_WEB_AUTH_DOMAIN'] ?? '';
  static String get webClientId => dotenv.env['FIREBASE_WEB_CLIENT_ID'] ?? '';
  static String get androidApiKey => dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? '';
  static String get androidAppId => dotenv.env['FIREBASE_ANDROID_APP_ID'] ?? '';

  static String require(String name, String value) {
    if (value.isEmpty) {
      throw StateError(
        'Missing $name. Provide it in frontend/.env.',
      );
    }
    return value;
  }

  static void validateWeb() {
    require('FIREBASE_PROJECT_ID', projectId);
    require('FIREBASE_WEB_API_KEY', webApiKey);
    require('FIREBASE_WEB_APP_ID', webAppId);
    require('FIREBASE_WEB_AUTH_DOMAIN', webAuthDomain);
    require('FIREBASE_MESSAGING_SENDER_ID', messagingSenderId);
    require('FIREBASE_STORAGE_BUCKET', storageBucket);
  }

  static void validateAndroid() {
    require('FIREBASE_PROJECT_ID', projectId);
    require('FIREBASE_ANDROID_API_KEY', androidApiKey);
    require('FIREBASE_ANDROID_APP_ID', androidAppId);
    require('FIREBASE_MESSAGING_SENDER_ID', messagingSenderId);
    require('FIREBASE_STORAGE_BUCKET', storageBucket);
  }
}