import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load tokens from secure storage on app startup
  try {
    await AuthService().loadFromStorage();
  } catch (e) {
    print('Failed to load tokens from storage: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => MyAppState(),
      child: const MyApp(),
    ),
  );
}
