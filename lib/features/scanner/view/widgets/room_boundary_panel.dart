import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Room boundary switch and room size picker.
class RoomBoundaryPanel extends StatelessWidget {
  const RoomBoundaryPanel({
    super.key,
    required this.enabled,
    required this.preset,
    required this.onToggle,
    required this.onPresetSelected,
  });

  final bool enabled;
  final RoomSizePreset preset;
  final ValueChanged<bool> onToggle;
  final ValueChanged<RoomSizePreset> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tone = enabled ? scheme.primary : scheme.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.only(left: 12.w, right: 4.w),
      decoration: BoxDecoration(
        color: enabled
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(
          color: enabled
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.meeting_room_rounded : Icons.public_rounded,
            size: 20.w,
            color: tone,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    enabled
                        ? 'scan_boundary_on'.tr()
                        : 'scan_boundary_off'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: enabled ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  Text(
                    enabled
                        ? 'scan_boundary_limit'.tr(
                            args: {'room': preset.labelKey.tr()},
                          )
                        : 'scan_boundary_unrestricted'.tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (enabled)
            PopupMenuButton<RoomSizePreset>(
              initialValue: preset,
              tooltip: 'scan_boundary_size_tooltip'.tr(),
              icon: Icon(Icons.tune_rounded, size: 20.w, color: scheme.primary),
              onSelected: onPresetSelected,
              itemBuilder: (context) => [
                for (final p in RoomSizePreset.values)
                  PopupMenuItem<RoomSizePreset>(
                    value: p,
                    child: Text(p.labelKey.tr()),
                  ),
              ],
            ),
          Switch.adaptive(value: enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}
