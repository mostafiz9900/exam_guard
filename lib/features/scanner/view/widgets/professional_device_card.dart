import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:exam_guard/features/scanner/view/distance_text.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_group.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view/device_type_labels.dart';
import 'package:exam_guard/features/scanner/view/widgets/signal_bars_widget.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart'
    show ProximityBand;

/// Minimum touch target for buttons on the card.
const double _tapTarget = 40;

/// Strong signal = close = suspicious, so it is red (same thresholds as
/// the dashboard: > -65 dBm strong, > -75 dBm near).
Color signalColorFor(int rssi) =>
    signalColorForBand(ProximityBand.fromRssi(rssi));

Color signalColorForBand(ProximityBand band) => switch (band) {
  ProximityBand.veryClose => const Color(0xFFEF4444),
  ProximityBand.near => const Color(0xFFF97316),
  ProximityBand.inRange => const Color(0xFFF59E0B),
  ProximityBand.distant => const Color(0xFF10B981),
};

IconData _categoryIcon(String type) {
  if (type == 'Wi-Fi Access Point') return Icons.router_rounded;
  if (type == 'Computer / Laptop') return Icons.laptop_rounded;
  if (type == 'Bluetooth Device') return Icons.bluetooth_rounded;
  if (type.contains('Hotspot') || type.contains('AP')) {
    return Icons.wifi_tethering_rounded;
  }
  if (type.contains('Audio')) return Icons.headset_mic_rounded;
  if (type.contains('Wearable')) return Icons.watch_rounded;
  if (type.contains('Smartphone')) return Icons.smartphone_rounded;
  if (type.contains('ESP32')) return Icons.developer_board_rounded;
  return Icons.bluetooth_searching_rounded;
}

enum _CardMenu { details, seatSweep, select }

/// One likely physical device. When several addresses were grouped, a
/// "+N IDs" row expands to list each address, each still trackable and
/// loggable on its own.
///
/// Only BLE devices can be found on the radar (it needs a live signal);
/// classic Bluetooth and Wi-Fi results update every ~30 s. Trusted devices
/// are shown muted with a shield; devices that went quiet are muted with
/// "last seen Xs ago".
///
/// Live values never change the card's height: the NEW badge sits inline
/// with the name, "last seen Xs ago" replaces the clock, the signal and
/// label have fixed slots. Rarer changes (tags after classification,
/// connect, group expand) animate briefly.
class ProfessionalDeviceCard extends HookWidget {
  const ProfessionalDeviceCard({
    super.key,
    required this.group,
    required this.onTrackTap,
    required this.onLogTap,
    required this.onInfoTap,
    required this.onDisconnectTap,
    this.band,
    this.isTrusted = false,
    this.hasNewAlert = false,
    this.isStale = false,
    this.secondsSinceSeen = 0,
    this.isSelecting = false,
    this.isSelected = false,
    this.canSeatSweep = false,
    this.onSeatSweepTap,
    this.onSelectTap,
  });

  final ScannedDeviceGroup group;

  /// Proximity of the primary (smoothed, with hysteresis). Derived from
  /// its signal when null.
  final ProximityBand? band;

  /// The device belongs to the room or the invigilator.
  final bool isTrusted;

  /// Appeared after the baseline and not yet acknowledged.
  final bool hasNewAlert;

  /// Not heard for a while; shown muted until it is removed.
  final bool isStale;
  final int secondsSinceSeen;

  /// Multi-select mode: a tap picks the card instead of opening details.
  final bool isSelecting;
  final bool isSelected;

  /// "Seat sweep" is offered (BLE device, exam with a seat layout).
  final bool canSeatSweep;
  final ValueChanged<ScannedDeviceModel> onTrackTap;
  final ValueChanged<ScannedDeviceModel> onLogTap;
  final ValueChanged<ScannedDeviceModel> onInfoTap;
  final ValueChanged<ScannedDeviceModel> onDisconnectTap;
  final ValueChanged<ScannedDeviceModel>? onSeatSweepTap;

  /// Picks / unpicks the card for "Walk & find" (long press, menu, or tap
  /// while selecting).
  final ValueChanged<ScannedDeviceModel>? onSelectTap;

  @override
  Widget build(BuildContext context) {
    final expanded = useState(false);
    final device = group.primary;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final proximity = band ?? ProximityBand.fromRssi(device.rssi);
    final signalColor = isStale
        ? scheme.onSurfaceVariant
        : signalColorForBand(proximity);
    final icon = _categoryIcon(device.deviceType);
    final canTrack = device.isBle;
    final canSelect = device.isBle && onSelectTap != null;

    final trackButton = OutlinedButton.icon(
      onPressed: canTrack ? () => onTrackTap(device) : null,
      icon: const Icon(Icons.radar_rounded, size: 16),
      label: Text(
        'scan_find'.tr(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, _tapTarget),
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );

    final leading = Container(
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelecting && isSelected
            ? scheme.primary
            : signalColor.withValues(alpha: 0.12),
      ),
      child: Icon(
        isSelecting
            ? (isSelected
                  ? Icons.check_rounded
                  : (canSelect ? Icons.circle_outlined : Icons.block_rounded))
            : icon,
        color: isSelecting && isSelected ? scheme.onPrimary : signalColor,
        size: 18.w,
      ),
    );

    final card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(
          color: isSelected
              ? scheme.primary
              : hasNewAlert
              ? scheme.error
              : signalColor.withValues(alpha: isTrusted ? 0.15 : 0.35),
          width: hasNewAlert || isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: isSelecting
            ? (canSelect ? () => onSelectTap!(device) : null)
            : () => onInfoTap(device),
        onLongPress: canSelect && !isSelecting
            ? () => onSelectTap!(device)
            : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 6.h),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isTrusted) ...[
                                Tooltip(
                                  message: 'scan_trusted_badge'.tr(),
                                  child: Icon(
                                    Icons.verified_user_rounded,
                                    size: 15.w,
                                    color: AppColors.success,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                              ],
                              Flexible(
                                child: Text(
                                  device.displayName,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Inline with the name: never adds a row.
                              if (hasNewAlert) ...[
                                SizedBox(width: 4.w),
                                _Tag(
                                  text: 'scan_new_badge'.tr(),
                                  color: scheme.error,
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 3.h),
                          // Tags only change when the classification does
                          // (rare); AnimatedSize smooths that.
                          Wrap(
                            spacing: 4.w,
                            runSpacing: 3.h,
                            children: [
                              _Tag(
                                icon: transportIcon(device.transport),
                                text: transportLabel(device.transport),
                                color: scheme.tertiary,
                              ),
                              _Tag(
                                icon: icon,
                                text: deviceTypeShortLabel(device.deviceType),
                                color: signalColor,
                              ),
                              _Tag(
                                text: manufacturerLabel(device.manufacturer),
                                color: scheme.primary,
                              ),
                              if (device.isHighSuspicion)
                                _Tag(
                                  icon: Icons.priority_high_rounded,
                                  text: 'scan_high_suspicion'.tr(),
                                  color: scheme.error,
                                ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  device.address,
                                  style: textTheme.labelSmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                isStale
                                    ? Icons.history_rounded
                                    : Icons.access_time_rounded,
                                size: 11.w,
                                color: isStale
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                isStale
                                    ? 'scan_last_seen_ago'.tr(
                                        args: {'seconds': '$secondsSinceSeen'},
                                      )
                                    : AppDateFormat.clock(device.lastSeen),
                                maxLines: 1,
                                style: textTheme.labelSmall?.copyWith(
                                  color: isStale
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SignalBarsWidget(
                              bars: isStale ? 0 : proximity.bars,
                              color: signalColor,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              device.isBle
                                  ? approxDistanceText(
                                      device.rssi,
                                      txPower: device.txPower,
                                    )
                                  : '${device.rssi} dBm',
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: signalColor,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          isStale
                              ? 'scan_proximity_quiet'.tr()
                              : proximity.labelKey.tr(),
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: signalColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (device.isConnected)
                  _ConnectedStrip(
                    batteryLevel: device.batteryLevel,
                    onDisconnect: () => onDisconnectTap(device),
                  ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Expanded(
                      child: canTrack
                          ? trackButton
                          : Tooltip(
                              message: 'scan_track_ble_only'.tr(),
                              triggerMode: TooltipTriggerMode.tap,
                              child: trackButton,
                            ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onLogTap(device),
                        icon: const Icon(
                          Icons.report_problem_rounded,
                          size: 16,
                        ),
                        label: Text(
                          'scan_log_violation'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, _tapTarget),
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _tapTarget,
                      height: _tapTarget,
                      child: PopupMenuButton<_CardMenu>(
                        tooltip: 'scan_more_actions'.tr(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert_rounded, size: 20),
                        onSelected: (choice) => switch (choice) {
                          _CardMenu.details => onInfoTap(device),
                          _CardMenu.seatSweep => onSeatSweepTap?.call(device),
                          _CardMenu.select => onSelectTap?.call(device),
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: _CardMenu.details,
                            child: _MenuRow(
                              icon: Icons.info_outline_rounded,
                              text: device.isBle
                                  ? 'scan_inspect_payload'.tr()
                                  : 'scan_device_details'.tr(),
                            ),
                          ),
                          if (canSeatSweep && onSeatSweepTap != null)
                            PopupMenuItem(
                              value: _CardMenu.seatSweep,
                              child: _MenuRow(
                                icon: Icons.event_seat_rounded,
                                text: 'scan_seat_sweep'.tr(),
                              ),
                            ),
                          if (canSelect && !isSelecting)
                            PopupMenuItem(
                              value: _CardMenu.select,
                              child: _MenuRow(
                                icon: Icons.checklist_rounded,
                                text: 'scan_select'.tr(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (group.isGrouped)
                  _GroupToggle(
                    extraIds: group.others.length,
                    expanded: expanded.value,
                    onTap: () => expanded.value = !expanded.value,
                  ),
                if (group.isGrouped && expanded.value)
                  _GroupMembers(
                    members: group.others,
                    onTrackTap: onTrackTap,
                    onLogTap: onLogTap,
                    onInfoTap: onInfoTap,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final muted = isStale || (isTrusted && !hasNewAlert);
    return muted ? Opacity(opacity: isStale ? 0.55 : 0.6, child: card) : card;
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 12),
      Flexible(child: Text(text)),
    ],
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 140.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11.w, color: color),
              SizedBox(width: 3.w),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedStrip extends StatelessWidget {
  const _ConnectedStrip({
    required this.batteryLevel,
    required this.onDisconnect,
  });

  final int? batteryLevel;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontWeight: FontWeight.bold, color: AppColors.success);
    return Container(
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsetsDirectional.only(start: 8.w),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 14.w, color: AppColors.success),
          SizedBox(width: 4.w),
          Text('scan_connected_badge'.tr(), style: style),
          if (batteryLevel != null) ...[
            SizedBox(width: 10.w),
            Icon(
              Icons.battery_std_rounded,
              size: 13.w,
              color: AppColors.success,
            ),
            Text('$batteryLevel%', style: style),
          ],
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: scheme.error,
              minimumSize: const Size(0, _tapTarget),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onDisconnect,
            icon: const Icon(Icons.link_off_rounded, size: 16),
            label: Text('scan_disconnect'.tr()),
          ),
        ],
      ),
    );
  }
}

class _GroupToggle extends StatelessWidget {
  const _GroupToggle({
    required this.extraIds,
    required this.expanded,
    required this.onTap,
  });

  final int extraIds;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: Material(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.r),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _tapTarget),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Row(
                children: [
                  Icon(
                    Icons.layers_rounded,
                    size: 16.w,
                    color: scheme.onSecondaryContainer,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'scan_group_chip'.tr(args: {'count': '$extraIds'}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupMembers extends StatelessWidget {
  const _GroupMembers({
    required this.members,
    required this.onTrackTap,
    required this.onLogTap,
    required this.onInfoTap,
  });

  final List<ScannedDeviceModel> members;
  final ValueChanged<ScannedDeviceModel> onTrackTap;
  final ValueChanged<ScannedDeviceModel> onLogTap;
  final ValueChanged<ScannedDeviceModel> onInfoTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
            child: Text(
              'scan_group_explain'.tr(),
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final m in members)
            InkWell(
              borderRadius: BorderRadius.circular(8.r),
              onTap: () => onInfoTap(m),
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: 4.w),
                child: Row(
                  children: [
                    if (m.isConnected) ...[
                      Icon(
                        Icons.link_rounded,
                        size: 14.w,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 4.w),
                    ],
                    Expanded(
                      child: Text(
                        m.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Text(
                      '${m.rssi} dBm',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: signalColorFor(m.rssi),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.radar_rounded, size: 20),
                      tooltip: 'scan_track_radar'.tr(),
                      color: scheme.primary,
                      constraints: const BoxConstraints.tightFor(
                        width: _tapTarget,
                        height: _tapTarget,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => onTrackTap(m),
                    ),
                    IconButton(
                      icon: const Icon(Icons.report_problem_rounded, size: 20),
                      tooltip: 'scan_log_violation'.tr(),
                      color: scheme.error,
                      constraints: const BoxConstraints.tightFor(
                        width: _tapTarget,
                        height: _tapTarget,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => onLogTap(m),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
