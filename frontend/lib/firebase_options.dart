// Environment-driven Firebase options.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'config/firebase_env.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Firebase is not configured for iOS in this workspace yet.',
        );
      case TargetPlatform.macOS:
  throw UnsupportedError(
          'Firebase is not configured for macOS in this workspace yet.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'Firebase is not configured for Windows in this workspace yet.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase is not configured for Linux in this workspace yet.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web {
    FirebaseEnv.validateWeb();
    return FirebaseOptions(
      apiKey: FirebaseEnv.webApiKey,
      appId: FirebaseEnv.webAppId,
      messagingSenderId: FirebaseEnv.messagingSenderId,
      projectId: FirebaseEnv.projectId,
      authDomain: FirebaseEnv.webAuthDomain,
      storageBucket: FirebaseEnv.storageBucket,
    );
  }

  static FirebaseOptions get android {
    FirebaseEnv.validateAndroid();
    return FirebaseOptions(
      apiKey: FirebaseEnv.androidApiKey,
      appId: FirebaseEnv.androidAppId,
      messagingSenderId: FirebaseEnv.messagingSenderId,
      projectId: FirebaseEnv.projectId,
      storageBucket: FirebaseEnv.storageBucket,
    );
  }
}
