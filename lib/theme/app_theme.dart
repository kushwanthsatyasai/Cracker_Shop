import 'package:flutter/material.dart';

class AppTheme {
  // Light theme colors matching React app
  static const Color primary = Color(0xFFFF8C00); // Orange 25 95% 53%
  static const Color primaryForeground = Colors.white;
  static const Color secondary = Color(0xFFFFF8E1); // Light yellow 45 100% 96%
  static const Color secondaryForeground = Color(0xFF1A0F0F); // Dark brown 340 80% 8%
  static const Color accent = Color(0xFFFF7043); // Orange-red 15 100% 70%
  static const Color accentForeground = Colors.white;
  static const Color background = Color(0xFFFFFBF5); // Light cream 35 100% 98%
  static const Color foreground = Color(0xFF1A0F0F); // Dark brown 340 80% 8%
  static const Color card = Colors.white;
  static const Color cardForeground = Color(0xFF1A0F0F);
  static const Color muted = Color(0xFFF5F3E8); // Light yellow 45 50% 95%
  static const Color mutedForeground = Color(0xFF7A6B5A); // Brown 25 8% 45%
  static const Color border = Color(0xFFE8E0D0); // Light brown 45 30% 88%
  static const Color input = Color(0xFFF0E8D8); // Light cream 45 30% 92%
  static const Color ring = Color(0xFFFF8C00); // Orange 25 95% 53%
  static const Color destructive = Color(0xFFE53E3E); // Red 0 84% 60%
  static const Color destructiveForeground = Colors.white;
  static const Color success = Color(0xFF38A169); // Green 142 76% 36%
  static const Color successForeground = Colors.white;
  static const Color warning = Color(0xFFF6AD55); // Orange 38 92% 50%
  static const Color warningForeground = Colors.white;
  
  // Festive colors
  static const Color festiveGold = Color(0xFFFFD700); // Gold 45 100% 60%
  static const Color festiveRed = Color(0xFFE53E3E); // Red 350 85% 60%
  static const Color festiveGreen = Color(0xFF48BB78); // Green 142 69% 58%

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: primaryForeground,
        secondary: secondary,
        onSecondary: secondaryForeground,
        tertiary: accent,
        onTertiary: accentForeground,
        surface: card,
        onSurface: cardForeground,
        error: destructive,
        onError: destructiveForeground,
        outline: border,
        outlineVariant: border,
        surfaceContainerHighest: muted,
        onSurfaceVariant: mutedForeground,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ring, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: destructive),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: primaryForeground,
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: primaryForeground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: primaryForeground,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      scaffoldBackgroundColor: background,
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: muted,
        selectedColor: primary,
        labelStyle: const TextStyle(color: mutedForeground),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: primary,
        textColor: primaryForeground,
      ),
    );
  }

  // Dark theme (if needed)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: primaryForeground,
        secondary: Color(0xFF2A1F1F), // Dark brown
        onSecondary: Color(0xFFF5F3E8), // Light cream
        tertiary: accent,
        onTertiary: accentForeground,
        surface: Color(0xFF2A1F1F), // Dark brown
        onSurface: Color(0xFFF5F3E8), // Light cream
        error: destructive,
        onError: destructiveForeground,
        outline: Color(0xFF3A2F2F), // Darker brown
        outlineVariant: Color(0xFF3A2F2F), // Darker brown
        surfaceContainerHighest: Color(0xFF2A1F1F), // Dark brown
        onSurfaceVariant: Color(0xFFB8A99A), // Light brown
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2A1F1F),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF3A2F2F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A2F2F)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A2F2F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ring, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: destructive),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: primaryForeground,
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2A1F1F),
        foregroundColor: Color(0xFFF5F3E8),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFFF5F3E8),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      scaffoldBackgroundColor: const Color(0xFF1A0F0F),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF3A2F2F),
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2A1F1F),
        selectedColor: primary,
        labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: primary,
        textColor: primaryForeground,
      ),
    );
  }
} 