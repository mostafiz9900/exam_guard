import 'package:flutter/material.dart';

/// Centralized color palette for ExamGuard.
///
/// All theme colors are defined here to avoid magic colors across the app.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF4B7CFE);
  static const Color primaryDark = Color(0xFF2A4DCC);
  static const Color secondary = Color(0xFF00D6A5);
  static const Color background = Color(0xFF111827);
  static const Color surface = Color(0xFF1E293B);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color textHighEmphasis = Color(0xFFF8FAFC);
  static const Color textMediumEmphasis = Color(0xFF94A3B8);
  static const Color textLowEmphasis = Color(0xFF64748B);
  static const Color onPrimary = textHighEmphasis;
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color disabled = Color(0xFF334155);
  static const Color border = Color(0xFF334155);
  static const Color shimmerBase = Color(0xFF263247);
  static const Color shimmerHighlight = Color(0xFF334155);
  static const Color transparent = Color(0x00000000);
  static const Color shadow = Color(0x1F000000);
}
