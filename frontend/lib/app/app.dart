import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import '../pages/home_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final seed = Colors.cyan;

        final lightScheme =
            lightDynamic?.harmonized() ?? ColorScheme.fromSeed(seedColor: seed);

        final darkScheme =
            darkDynamic?.harmonized() ??
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

        return MaterialApp(
          title: 'Hookd',
          themeMode: ThemeMode.system,
          theme: ThemeData(useMaterial3: true, colorScheme: lightScheme),
          darkTheme: ThemeData(useMaterial3: true, colorScheme: darkScheme),
          home: const MyHomePage(),
        );
      },
    );
  }
}
