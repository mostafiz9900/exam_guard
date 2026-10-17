import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Filter chips, the discovered count and the List / Radar map switch.
/// Pinned under the app bar while the device list scrolls.
class ScannerListHeader extends StatelessWidget {
  const ScannerListHeader({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.deviceCount,
    required this.signalCount,
    required this.isRadarMap,
    required this.onRadarMapChanged,
  });

  final DeviceFilter filter;
  final ValueChanged<DeviceFilter> onFilterChanged;

  /// Shown devices (grouped addresses count once).
  final int deviceCount;

  /// BLE addresses behind [deviceCount].
  final int signalCount;
  final bool isRadarMap;
  final ValueChanged<bool> onRadarMapChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final gutter = AppDimens.spacingMedium;

    return Material(
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 6.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: Row(
              children: [
                for (final f in DeviceFilter.values)
                  Padding(
                    padding: EdgeInsetsDirectional.only(end: 6.w),
                    child: FilterChip(
                      label: Text(f.labelKey.tr()),
                      selected: filter == f,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => onFilterChanged(f),
                      labelStyle: textTheme.labelMedium?.copyWith(
                        fontWeight: filter == f
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: filter == f
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      selectedColor: scheme.secondaryContainer,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 4.h, gutter, 6.h),
            child: Row(
              children: [
                Icon(Icons.radar_rounded, size: 16.w, color: scheme.secondary),
                SizedBox(width: 6.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'scan_discovered_count'.tr(
                          args: {'count': '$deviceCount'},
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (signalCount != deviceCount)
                        Text(
                          'scan_signal_summary'.tr(
                            args: {
                              'devices': '$deviceCount',
                              'signals': '$signalCount',
                            },
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.view_list_rounded, size: 18),
                      tooltip: 'scan_view_list'.tr(),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.radar_rounded, size: 18),
                      tooltip: 'scan_view_radar'.tr(),
                    ),
                  ],
                  selected: {isRadarMap},
                  onSelectionChanged: (s) => onRadarMapChanged(s.first),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
        ],
      ),
    );
  }
}
