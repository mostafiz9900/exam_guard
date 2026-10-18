import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Filter chips, the discovered count, the list order (Stable / Nearest
/// first) and the List / Radar map switch.
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
    required this.sortMode,
    required this.onSortModeChanged,
    this.transportCounts = const {},
  });

  final ScanSortMode sortMode;
  final ValueChanged<ScanSortMode> onSortModeChanged;

  /// Shown devices per transport; a "BLE 12 · Classic 2 · Wi-Fi 5" line
  /// appears once anything other than BLE is in the list.
  final Map<DeviceTransport, int> transportCounts;

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
                      if ((transportCounts[DeviceTransport.classic] ?? 0) +
                              (transportCounts[DeviceTransport.wifi] ?? 0) >
                          0)
                        Text(
                          'scan_transport_counts'.tr(
                            args: {
                              'ble':
                                  '${transportCounts[DeviceTransport.ble] ?? 0}',
                              'classic':
                                  '${transportCounts[DeviceTransport.classic] ?? 0}',
                              'wifi':
                                  '${transportCounts[DeviceTransport.wifi] ?? 0}',
                            },
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
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
                SizedBox(width: 4.w),
                PopupMenuButton<ScanSortMode>(
                  tooltip: 'scan_sort_tooltip'.tr(
                    args: {'mode': sortMode.labelKey.tr()},
                  ),
                  initialValue: sortMode,
                  onSelected: onSortModeChanged,
                  icon: Icon(
                    sortMode == ScanSortMode.stable
                        ? Icons.low_priority_rounded
                        : Icons.near_me_rounded,
                    color: scheme.primary,
                  ),
                  itemBuilder: (_) => [
                    for (final m in ScanSortMode.values)
                      CheckedPopupMenuItem(
                        value: m,
                        checked: m == sortMode,
                        child: Text(m.labelKey.tr()),
                      ),
                  ],
                ),
                SizedBox(width: 6.w),
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
