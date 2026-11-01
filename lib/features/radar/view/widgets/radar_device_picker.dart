import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/widgets/app_bottom_sheet.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_text_context_menu.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/device_type_labels.dart';
import 'package:exam_guard/features/scanner/view/distance_text.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Opens the picker as a sheet (to switch the radar's target).
Future<ScannedDeviceModel?> showRadarDevicePicker(
  BuildContext context, {
  String? currentId,
}) => showAppBottomSheet<ScannedDeviceModel>(
  context: context,
  showDragHandle: true,
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.85,
    child: RadarDevicePicker(
      currentId: currentId,
      onPick: (d) => Navigator.pop(context, d),
    ),
  ),
);

/// "Which device do you want to find?": nearby Bluetooth (BLE) devices,
/// closest first, with distance and warning badges. Only BLE can be
/// tracked live; classic Bluetooth and Wi-Fi are heard too rarely.
class RadarDevicePicker extends HookConsumerWidget {
  const RadarDevicePicker({super.key, required this.onPick, this.currentId});

  final ValueChanged<ScannedDeviceModel> onPick;

  /// The device being tracked now, marked in the list.
  final String? currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scannerViewModelProvider);
    final query = useState('');
    final onlyUntrusted = useState(false);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final q = query.value.trim().toLowerCase();
    final groups = [
      for (final g in state.groups)
        if (g.primary.isBle &&
            !state.isGroupStale(g) &&
            (!onlyUntrusted.value || !state.isGroupTrusted(g)) &&
            (q.isEmpty || _matches(g, q)))
          g,
    ]..sort((a, b) => b.strongestRssi.compareTo(a.strongestRssi));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimens.spacingMedium,
            AppDimens.spacingSmall,
            AppDimens.spacingMedium,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'radar_pick_title'.tr(),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'radar_pick_subtitle'.tr(),
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              SizedBox(height: AppDimens.spacingSmall),
              TextField(
                key: const Key('radar_pick_search'),
                contextMenuBuilder: appTextContextMenu,
                onChanged: (v) => query.value = v,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'radar_pick_search'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  ),
                ),
              ),
              SizedBox(height: AppDimens.spacingSmall),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('radar_pick_all'.tr()),
                    selected: !onlyUntrusted.value,
                    onSelected: (_) => onlyUntrusted.value = false,
                  ),
                  ChoiceChip(
                    key: const Key('radar_pick_untrusted'),
                    label: Text('radar_pick_untrusted'.tr()),
                    selected: onlyUntrusted.value,
                    onSelected: (_) => onlyUntrusted.value = true,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: AppDimens.spacingSmall),
        Expanded(
          child: !state.isScanning
              ? _Empty(
                  icon: Icons.bluetooth_disabled_rounded,
                  title: 'radar_pick_not_scanning'.tr(),
                  text: 'radar_pick_not_scanning_text'.tr(),
                  action: 'open_scanner'.tr(),
                  onAction: () => context.pushTo(AppRoute.scanner),
                )
              : groups.isEmpty
              ? _Empty(
                  icon: Icons.bluetooth_searching_rounded,
                  title: q.isEmpty && !onlyUntrusted.value
                      ? 'radar_pick_empty'.tr()
                      : 'radar_pick_no_match'.tr(),
                  text: 'radar_pick_empty_text'.tr(),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppDimens.spacingMedium,
                    0,
                    AppDimens.spacingMedium,
                    AppDimens.spacingMedium,
                  ),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => SizedBox(height: 6.h),
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    return _DeviceRow(
                      group: g,
                      isCurrent: g.members.any((m) => m.id == currentId),
                      isTrusted: state.isGroupTrusted(g),
                      hasAlert: state.hasUnacknowledgedAlert(g),
                      isToggling: g.members.any(
                        (m) => state.togglingIds.contains(m.id),
                      ),
                      onTap: () => onPick(g.primary),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static bool _matches(ScannedDeviceGroup g, String q) => g.members.any(
    (m) =>
        m.displayName.toLowerCase().contains(q) ||
        m.manufacturer.toLowerCase().contains(q) ||
        deviceTypeShortLabel(m.deviceType).toLowerCase().contains(q) ||
        m.id.toLowerCase().contains(q),
  );
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.group,
    required this.isCurrent,
    required this.isTrusted,
    required this.hasAlert,
    required this.isToggling,
    required this.onTap,
  });

  final ScannedDeviceGroup group;
  final bool isCurrent;
  final bool isTrusted;
  final bool hasAlert;
  final bool isToggling;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final d = group.primary;
    final rssi = group.strongestRssi;
    final suspicious = d.isHighSuspicion || hasAlert;
    final accent = suspicious
        ? colors.error
        : isCurrent
        ? colors.primary
        : colors.outlineVariant;

    Widget tag(String text, Color color, {IconData? icon}) => Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11.w, color: color),
            SizedBox(width: 2.w),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      key: ValueKey('radar_pick_${d.id}'),
      color: isCurrent
          ? colors.primaryContainer.withValues(alpha: 0.35)
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(
          color: accent,
          width: suspicious || isCurrent ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppDimens.spacingSmall),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor: (suspicious ? colors.error : colors.primary)
                    .withValues(alpha: 0.12),
                child: Icon(
                  transportIcon(d.transport),
                  size: 18.w,
                  color: suspicious ? colors.error : colors.primary,
                ),
              ),
              SizedBox(width: AppDimens.spacingSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        tag(deviceTypeShortLabel(d.deviceType), colors.primary),
                        if (hasAlert)
                          tag(
                            'radar_pick_new'.tr(),
                            colors.error,
                            icon: Icons.notification_important_rounded,
                          ),
                        if (d.isHighSuspicion)
                          tag(
                            'scan_high_suspicion'.tr(),
                            colors.error,
                            icon: Icons.priority_high_rounded,
                          ),
                        if (isToggling)
                          tag(
                            'scan_toggling'.tr(),
                            Colors.orange.shade800,
                            icon: Icons.power_settings_new_rounded,
                          ),
                        if (isTrusted)
                          tag(
                            'radar_pick_trusted'.tr(),
                            colors.outline,
                            icon: Icons.verified_user_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    approxDistanceText(rssi, txPower: d.txPower),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    isCurrent
                        ? 'radar_pick_tracking'.tr()
                        : 'radar_pick_track'.tr(),
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: EdgeInsets.all(AppDimens.spacingLarge),
      children: [
        Icon(icon, size: 48.w, color: colors.onSurfaceVariant),
        SizedBox(height: AppDimens.spacingSmall),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 4.h),
        Text(
          text,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (action != null) ...[
          SizedBox(height: AppDimens.spacingMedium),
          Center(
            child: FilledButton.tonal(
              onPressed: onAction,
              child: Text(action!),
            ),
          ),
        ],
      ],
    );
  }
}
