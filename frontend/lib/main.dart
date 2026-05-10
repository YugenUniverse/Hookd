import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
