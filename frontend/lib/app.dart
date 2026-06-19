import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'navigation/app_router.dart';
import 'theme/app_theme.dart';
import 'utils/theme_controller.dart';

class CbtDiaryApp extends StatelessWidget {
  const CbtDiaryApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (
        context,
        themeMode,
        child,
      ) {
        return MaterialApp.router(
          title: 'КПТ-дневник',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: appRouter,

          builder: (context, child) {
            final theme = Theme.of(context);

            final isDark =
                theme.brightness == Brightness.dark;

            final overlayStyle = SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,

              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,

              statusBarBrightness: isDark
                  ? Brightness.dark
                  : Brightness.light,

              systemNavigationBarColor:
                  Colors.transparent,

              systemNavigationBarDividerColor:
                  Colors.transparent,

              systemNavigationBarIconBrightness:
                  isDark
                  ? Brightness.light
                  : Brightness.dark,

              systemNavigationBarContrastEnforced:
                  false,

              systemStatusBarContrastEnforced:
                  false,
            );

            return AnnotatedRegion<
                SystemUiOverlayStyle>(
              value: overlayStyle,
              child: ColoredBox(

                color: theme.scaffoldBackgroundColor,
                child: child ??
                    const SizedBox.shrink(),
              ),
            );
          },
        );
      },
    );
  }
}