import 'dart:io' show File;

import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/report/view/widgets/photo_viewer.dart';
import 'package:exam_guard/features/report/view/widgets/severity_style.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';

/// One incident on the report: device, severity, seat, details, notes and
/// evidence photo thumbnails (tap to view full screen).
class IncidentLogCard extends StatelessWidget {
  const IncidentLogCard({super.key, required this.log});

  final ActionLogModel log;

  static String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '-' : value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = reportSeverityColor(log.severity);
    final seat = log.seat?.trim() ?? '';

    Widget chip(String text, Color fg, Color bg, {IconData? icon}) => Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.w, color: fg),
            SizedBox(width: 3.w),
          ],
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    final caption = [
      AppDateFormat.shortDateTime(log.createdAt),
      if (seat.isNotEmpty) 'report_seat'.tr(args: {'seat': seat}),
      log.deviceName,
    ].join(' · ');

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingSmall),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.report_problem_rounded,
                color: color,
                size: 20.w,
              ),
            ),
            SizedBox(width: AppDimens.spacingSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          log.deviceName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      chip(
                        reportSeverityLabel(log.severity),
                        color,
                        color.withValues(alpha: 0.12),
                      ),
                    ],
                  ),
                  if (seat.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    chip(
                      'report_seat'.tr(args: {'seat': seat}),
                      colors.onPrimaryContainer,
                      colors.primaryContainer,
                      icon: Icons.event_seat_rounded,
                    ),
                  ],
                  SizedBox(height: 4.h),
                  Text(
                    'report_log_details'.tr(
                      args: {
                        'location': log.location.trim().isEmpty
                            ? 'report_not_recorded'.tr()
                            : log.location,
                        'id': _orDash(log.deviceId),
                      },
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (log.notes.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      'report_note'.tr(args: {'note': log.notes}),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (log.photoPaths.isNotEmpty) ...[
                    SizedBox(height: AppDimens.spacingExtraSmall),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.w,
                      children: [
                        for (var i = 0; i < log.photoPaths.length; i++)
                          _Thumbnail(
                            path: log.photoPaths[i],
                            onTap: () => showPhotoViewer(
                              context,
                              paths: log.photoPaths,
                              initialIndex: i,
                              caption: caption,
                            ),
                          ),
                      ],
                    ),
                  ],
                  SizedBox(height: 4.h),
                  Text(
                    AppDateFormat.shortDateTime(log.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path, required this.onTap});

  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = 56.w.clamp(48.0, 80.0);
    final radius = BorderRadius.circular(AppDimens.radiusSmall);

    return Tooltip(
      message: 'report_photo_open'.tr(),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ClipRRect(
          borderRadius: radius,
          child: Image.file(
            File(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: 200,
            errorBuilder: (_, _, _) => Container(
              width: size,
              height: size,
              color: colors.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image_outlined,
                color: colors.onSurfaceVariant,
                size: 20.w,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
