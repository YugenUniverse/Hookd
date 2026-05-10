import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import '../pages/home_page.dart';
import '../services/auth_service.dart';
import '../dialogs/login_dialog.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final seed = Colors.cyan;

        final lightScheme =
            lightDynamic?.harmonized() ?? ColorScheme.fromSeed(seedColor: seed);

        final darkScheme = darkDynamic?.harmonized() ??
            ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'Hookd',
          themeMode: ThemeMode.system,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightScheme,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // No automatic login prompt on startup; UI will show explicit message.
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool _isDialogShowing = false;

  void _showLoginPrompt() {
    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoginDialog(),
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        // Only show home page if authenticated
        if (AuthService().isAuthenticated) {
          return const MyHomePage();
        }
        // Show a clear message when not logged in with a Login button
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Not logged in', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    if (!_isDialogShowing) _showLoginPrompt();
                  },
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
