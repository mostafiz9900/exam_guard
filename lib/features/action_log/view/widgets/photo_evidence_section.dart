import 'dart:io' show File;

import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

/// Thumbnails of the incident's evidence photos with remove buttons, and an
/// "Add photo" tile while more can be added.
class PhotoEvidenceSection extends StatelessWidget {
  const PhotoEvidenceSection({
    super.key,
    required this.photoPaths,
    required this.maxPhotos,
    required this.isTakingPhoto,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> photoPaths;
  final int maxPhotos;
  final bool isTakingPhoto;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final size = 76.w.clamp(64.0, 96.0);
    final radius = BorderRadius.circular(AppDimens.radiusSmall);
    final canAdd = photoPaths.length < maxPhotos;

    Widget thumbnail(String path) => SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: radius,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: 240,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: -8,
            end: -8,
            child: Material(
              color: colors.errorContainer,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? () => onRemove(path) : null,
                child: Tooltip(
                  message: 'incident_photo_remove'.tr(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final addTile = Material(
      color: colors.primaryContainer.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: enabled && !isTakingPhoto ? onAdd : null,
        child: SizedBox(
          width: size,
          height: size,
          child: isTakingPhoto
              ? Center(
                  child: SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: colors.primary),
                    SizedBox(height: 4.h),
                    Text(
                      'incident_photo_add'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 18.w,
              color: colors.primary,
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                'incident_photos'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              'incident_photo_count'.tr(
                args: {'count': '${photoPaths.length}', 'max': '$maxPhotos'},
              ),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: AppDimens.spacingSmall),
        Wrap(
          spacing: AppDimens.spacingSmall,
          runSpacing: AppDimens.spacingSmall,
          children: [
            for (final p in photoPaths) thumbnail(p),
            if (canAdd) addTile,
          ],
        ),
      ],
    );
  }
}
