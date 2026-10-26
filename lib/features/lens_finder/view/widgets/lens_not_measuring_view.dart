import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/lens_finder/view_model/lens_finder_view_model.dart';

/// Replaces the camera picture whenever the finder is not scanning. Grey
/// and explicit, so it can never be mistaken for "no lens found".
class LensNotMeasuringView extends StatelessWidget {
  const LensNotMeasuringView({
    super.key,
    required this.status,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final LensFinderStatus status;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final (IconData icon, String title, String body) = switch (status) {
      LensFinderStatus.permissionDenied => (
        Icons.no_photography_outlined,
        'lens_perm_title'.tr(),
        'lens_perm_text'.tr(),
      ),
      LensFinderStatus.noCamera => (
        Icons.videocam_off_outlined,
        'lens_no_camera_title'.tr(),
        'lens_no_camera_text'.tr(),
      ),
      LensFinderStatus.paused => (
        Icons.pause_circle_outline_rounded,
        'lens_paused_title'.tr(),
        'lens_paused_text'.tr(),
      ),
      _ => (
        Icons.error_outline_rounded,
        'lens_error_title'.tr(),
        'lens_error_text'.tr(),
      ),
    };

    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: colors.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(
                  'lens_not_scanning'.tr(),
                  textAlign: TextAlign.center,
                  style: text.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (status == LensFinderStatus.permissionDenied)
                      FilledButton.icon(
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: Text('lens_open_settings'.tr()),
                      ),
                    if (status != LensFinderStatus.noCamera)
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: Icon(
                          status == LensFinderStatus.paused
                              ? Icons.play_arrow_rounded
                              : Icons.refresh_rounded,
                          size: 18,
                        ),
                        label: Text(
                          (status == LensFinderStatus.paused
                                  ? 'lens_resume'
                                  : 'lens_retry')
                              .tr(),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
