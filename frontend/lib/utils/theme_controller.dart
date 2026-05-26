import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.system,
  );

  static void toggleTheme(BuildContext context) {
    final currentMode = themeMode.value;

    final platformBrightness = MediaQuery.platformBrightnessOf(context);

    final isCurrentlyDark = currentMode == ThemeMode.dark ||
        currentMode == ThemeMode.system &&
            platformBrightness == Brightness.dark;

    themeMode.value = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
  }

  static String getThemeTitle(BuildContext context) {
    final currentMode = themeMode.value;

    if (currentMode == ThemeMode.light) {
      return 'Светлая тема';
    }

    if (currentMode == ThemeMode.dark) {
      return 'Тёмная тема';
    }

    final platformBrightness = MediaQuery.platformBrightnessOf(context);

    if (platformBrightness == Brightness.dark) {
      return 'Системная: тёмная';
    }

    return 'Системная: светлая';
  }
}