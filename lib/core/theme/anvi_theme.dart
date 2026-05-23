import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'anvi_colors.dart';

class AnviTheme {
  const AnviTheme._();

  static ThemeData dark() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.spaceGroteskTextTheme(base.textTheme)
        .apply(bodyColor: AnviColors.bone, displayColor: AnviColors.bone);

    return base.copyWith(
      scaffoldBackgroundColor: AnviColors.voidBlack,
      colorScheme: const ColorScheme.dark(
        primary: AnviColors.moltenGold,
        secondary: AnviColors.ember,
        tertiary: AnviColors.crimson,
        surface: AnviColors.obsidian,
        onSurface: AnviColors.bone,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AnviColors.bone,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AnviColors.smokedGlass,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
      ),
    );
  }
}
