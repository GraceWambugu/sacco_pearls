import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// One theme for the whole app: forest green on a paper background, DM Sans text.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.forest).copyWith(
      primary: AppColors.forest,
      secondary: AppColors.accent,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      error: AppColors.red,
    ),
    scaffoldBackgroundColor: AppColors.paper,
  );
  return base.copyWith(
    // DM Sans is downloaded the first time the app runs; until then the default font is used.
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent,
    ),
  );
}
