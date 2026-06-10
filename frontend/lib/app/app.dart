import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dynamic_color/dynamic_color.dart';

import '../pages/home_page.dart';
import '../constants/ui_constants.dart';
import '../constants/nav_key.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  bool get _isDesktopLike {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => false,
      TargetPlatform.fuchsia => false,
      TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows =>
        true,
    };
  }

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

        return Builder(
          builder: (context) {
            final isCompact =
                _isDesktopLike || MediaQuery.sizeOf(context).shortestSide < 600;

            ThemeData buildTheme(ColorScheme scheme) {
              return ThemeData(
                useMaterial3: true,
                colorScheme: scheme,
                inputDecorationTheme: InputDecorationTheme(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isCompact ? AppSpacing.md : AppSpacing.lg,
                    vertical: isCompact ? AppSpacing.md : AppSpacing.lg,
                  ),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    minimumSize: Size(0, isCompact ? 52 : 48),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? AppSpacing.lg : AppSpacing.xl,
                      vertical: isCompact ? AppSpacing.lg : AppSpacing.lg,
                    ),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(0, isCompact ? 52 : 48),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? AppSpacing.lg : AppSpacing.xl,
                      vertical: isCompact ? AppSpacing.lg : AppSpacing.lg,
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    minimumSize: Size(0, isCompact ? 52 : 48),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? AppSpacing.md : AppSpacing.lg,
                      vertical: isCompact ? AppSpacing.md : AppSpacing.md,
                    ),
                  ),
                ),
                segmentedButtonTheme: SegmentedButtonThemeData(
                  style: ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(
                      Size(0, isCompact ? 52 : 48),
                    ),
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(
                        horizontal: isCompact ? AppSpacing.md : AppSpacing.lg,
                        vertical: isCompact ? AppSpacing.md : AppSpacing.md,
                      ),
                    ),
                  ),
                ),
              );
            }

            return MaterialApp(
              title: 'Hookd',
              navigatorKey: navigatorKey,
              themeMode: ThemeMode.system,
              theme: buildTheme(lightScheme),
              darkTheme: buildTheme(darkScheme),
              home: const MyHomePage(),
            );
          },
        );
      },
    );
  }
}
