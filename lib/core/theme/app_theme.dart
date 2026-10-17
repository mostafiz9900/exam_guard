import 'package:flutter/material.dart';

import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _theme(Brightness.light);
  static ThemeData get darkTheme => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.background : const Color(0xFFF7F9FC);
    final surface = isDark ? AppColors.surface : Colors.white;
    final onSurface = isDark
        ? AppColors.textHighEmphasis
        : const Color(0xFF172033);
    final muted = isDark
        ? AppColors.textMediumEmphasis
        : const Color(0xFF53627A);
    final border = isDark ? AppColors.border : const Color(0xFFD9E0EA);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        surface: surface,
        onSurface: onSurface,
        error: AppColors.error,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: AppDimens.heading1,
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: TextStyle(
          fontSize: AppDimens.heading2,
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: TextStyle(
          fontSize: AppDimens.heading3,
          color: onSurface,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          fontSize: AppDimens.bodyLarge,
          color: muted,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: AppDimens.bodyMedium,
          color: muted,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: AppDimens.bodySmall,
          color: muted,
          height: 1.4,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: isDark ? AppColors.primaryDark : AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimens.spacingMedium,
          vertical: AppDimens.spacingSmall,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: Size(0, AppDimens.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          ),
        ),
      ),
    );
  }
}
