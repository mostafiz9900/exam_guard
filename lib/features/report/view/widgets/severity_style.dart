import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';

/// Accent color of a severity on the report screen.
Color reportSeverityColor(LogSeverity severity) => switch (severity) {
  LogSeverity.critical => AppColors.error,
  LogSeverity.high => const Color(0xFFF97316),
  LogSeverity.medium => const Color(0xFFF59E0B),
  LogSeverity.low => const Color(0xFF10B981),
};

/// Translated severity label; the stored code stays English.
String reportSeverityLabel(LogSeverity severity) => switch (severity) {
  LogSeverity.critical => 'report_severity_critical'.tr(),
  LogSeverity.high => 'report_severity_high'.tr(),
  LogSeverity.medium => 'report_severity_medium'.tr(),
  LogSeverity.low => 'report_severity_low'.tr(),
};
