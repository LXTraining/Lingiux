import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF7C3AED);
  static const Color surface = Color(0xFF1C1B2E);
  static const Color background = Color(0xFF0F0E1A);
  static const Color surfaceVariant = Color(0xFF252438);
  static const Color onSurface = Color(0xFFE8E6F0);
  static const Color onSurfaceMuted = Color(0xFF9892B0);
  static const Color accent = Color(0xFF06B6D4);
  static const Color online = Color(0xFF10B981);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(0.2),
        elevation: 0,
      ),
    );
  }
}
