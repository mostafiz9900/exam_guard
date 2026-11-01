import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/utils/app_brand.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_bottom_sheet.dart';
import 'package:exam_guard/core/widgets/app_text_context_menu.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/action_log/model/seat_map.dart';
import 'package:exam_guard/features/hall_map/model/hall_locator.dart';
import 'package:exam_guard/features/hall_map/view/widgets/hall_map_canvas.dart';
import 'package:exam_guard/features/hall_map/view_model/hall_map_view_model.dart';

/// Live hall map: sensor nodes on their seats and the approximate area of
/// every suspicious device they hear.
class HallMapScreen extends HookConsumerWidget {
  const HallMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(hallMapProvider);
    final vm = ref.read(hallMapViewModelProvider.notifier);
    final placing = useState(false);
    final selectedNode = useState<String?>(null);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    // Placing starts with the first node that still needs a seat.
    void startPlacing() {
      placing.value = true;
      selectedNode.value =
          data.nodes
              .where((n) => n.seat == null)
              .map((n) => n.member.id)
              .firstOrNull ??
          data.nodes.firstOrNull?.member.id;
    }

    Future<void> onSeatTap(int row, int col) async {
      final id = selectedNode.value;
      if (!placing.value || id == null) return;
      final ok = await vm.place(id, row, col);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('hall_map_save_failed'.tr())));
        return;
      }
      // Move on to the next unplaced node.
      final next = data.nodes
          .where((n) => n.seat == null && n.member.id != id)
          .map((n) => n.member.id)
          .firstOrNull;
      if (next != null) selectedNode.value = next;
    }

    final gap = SizedBox(height: AppDimens.spacingMedium);
    return Scaffold(
      appBar: AppBar(
        title: Text('hall_map_title'.tr()),
        actions: [
          if (data.hasLayout && data.nodes.isNotEmpty)
            IconButton(
              key: const Key('hall_map_place_toggle'),
              tooltip:
                  (placing.value ? 'hall_map_place_done' : 'hall_map_place')
                      .tr(),
              onPressed: () =>
                  placing.value ? placing.value = false : startPlacing(),
              icon: Icon(
                placing.value
                    ? Icons.check_rounded
                    : Icons.edit_location_alt_outlined,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppDimens.spacingMedium),
          children: [
            if (!data.hasLayout)
              _LayoutForm(onSave: vm.setSeatLayout)
            else ...[
              _Summary(data: data),
              gap,
              if (data.nodes.isEmpty)
                _Notice(
                  icon: Icons.sensors_off_rounded,
                  text: 'hall_map_no_nodes'.tr(),
                  action: TextButton(
                    onPressed: () => context.pushTo(AppRoute.nodes),
                    child: Text('node_title'.tr()),
                  ),
                )
              else if (placing.value)
                _PlacingBar(
                  data: data,
                  selected: selectedNode.value,
                  onSelect: (id) => selectedNode.value = id,
                  onRemove: (id) => vm.remove(id),
                )
              else if (data.placedLive == 0 || data.hasUnplaced)
                _Notice(
                  key: const Key('hall_map_place_prompt'),
                  icon: Icons.edit_location_alt_outlined,
                  text:
                      (data.placedLive == 0
                              ? 'hall_map_place_first'
                              : 'hall_map_place_more')
                          .tr(),
                  action: FilledButton.tonal(
                    key: const Key('hall_map_place_start'),
                    onPressed: startPlacing,
                    child: Text('hall_map_place'.tr()),
                  ),
                ),
              SizedBox(height: AppDimens.spacingSmall),
              HallMapCanvas(
                data: data,
                placing: placing.value,
                selectedNode: selectedNode.value,
                onSeatTap: onSeatTap,
                onDeviceTap: (d) => _showDevice(context, d),
              ),
              SizedBox(height: AppDimens.spacingSmall),
              const _Legend(),
              gap,
              Text(
                'hall_map_devices'.tr(
                  args: {'count': '${data.devices.length}'},
                ),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: AppDimens.spacingSmall),
              if (data.devices.isEmpty)
                Text(
                  (data.placedLive == 0
                          ? 'hall_map_devices_need_nodes'
                          : 'hall_map_devices_none')
                      .tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                )
              else
                for (final d in data.devices)
                  _DeviceCard(device: d, onTap: () => _showDevice(context, d)),
              gap,
              Text(
                'hall_map_honesty'.tr(),
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static void _showDevice(BuildContext context, LocatedDevice d) =>
      showAppBottomSheet<void>(
        context: context,
        builder: (_) => _DeviceSheet(device: d),
      );
}

String _confidenceKey(LocatorConfidence c) => switch (c) {
  LocatorConfidence.good => 'hall_map_conf_good',
  LocatorConfidence.medium => 'hall_map_conf_medium',
  LocatorConfidence.low => 'hall_map_conf_low',
};

Color confidenceColor(LocatorConfidence c, ColorScheme colors) => switch (c) {
  LocatorConfidence.good => AppColors.success,
  LocatorConfidence.medium => Colors.orange.shade700,
  LocatorConfidence.low => colors.onSurfaceVariant,
};

String _metres(double seats) =>
    (seats * HallLocator.seatMeters).toStringAsFixed(1);

class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final HallMapData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final alerts = data.devices.where((d) => d.isAlert).length;
    Widget stat(String value, String label, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingSmall),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stat(
                  '${data.devices.length}',
                  'hall_map_stat_devices'.tr(),
                  colors.primary,
                ),
                stat(
                  '$alerts',
                  'hall_map_stat_alerts'.tr(),
                  alerts > 0 ? colors.error : colors.onSurfaceVariant,
                ),
                stat(
                  '${data.placedLive}/${data.nodes.length}',
                  'hall_map_stat_nodes'.tr(),
                  AppColors.success,
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  data.isCalibrated
                      ? Icons.tune_rounded
                      : Icons.info_outline_rounded,
                  size: 14.w,
                  color: data.isCalibrated
                      ? AppColors.success
                      : colors.onSurfaceVariant,
                ),
                SizedBox(width: 4.w),
                Flexible(
                  child: Text(
                    (data.isCalibrated
                            ? 'hall_map_calibrated'
                            : 'hall_map_not_calibrated')
                        .tr(),
                    key: const Key('hall_map_calibration'),
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(AppDimens.spacingSmall),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary, size: 20.w),
              SizedBox(width: AppDimens.spacingSmall),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Placing mode: pick a node, then tap its seat on the map.
class _PlacingBar extends StatelessWidget {
  const _PlacingBar({
    required this.data,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
  });

  final HallMapData data;
  final String? selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final node = data.nodes.where((n) => n.member.id == selected).firstOrNull;
    return Container(
      key: const Key('hall_map_placing'),
      padding: EdgeInsets.all(AppDimens.spacingSmall),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            node == null
                ? 'hall_map_pick_node'.tr()
                : 'hall_map_tap_seat'.tr(args: {'name': node.member.name}),
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              for (final n in data.nodes)
                InputChip(
                  key: Key('hall_map_node_${n.member.id}'),
                  selected: n.member.id == selected,
                  onSelected: (_) => onSelect(n.member.id),
                  onDeleted: n.seat == null
                      ? null
                      : () => onRemove(n.member.id),
                  deleteButtonTooltipMessage: 'hall_map_unplace'.tr(),
                  avatar: Icon(
                    n.isLive
                        ? Icons.sensors_rounded
                        : Icons.sensors_off_rounded,
                    size: 16.w,
                    color: n.isLive ? AppColors.success : colors.error,
                  ),
                  label: Text(
                    n.seat == null
                        ? AppBrand.shortNodeName(n.member.name)
                        : '${AppBrand.shortNodeName(n.member.name)} · '
                              '${SeatId.format(n.seat!.$1, n.seat!.$2)}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: colors.onSurfaceVariant);
    Widget item(Widget mark, String key) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: 4.w),
        Text(key.tr(), style: style),
      ],
    );
    Widget dot(Color c) => Container(
      width: 10.w,
      height: 10.w,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    return Wrap(
      spacing: 12.w,
      runSpacing: 4.h,
      children: [
        item(
          Icon(Icons.sensors_rounded, size: 14.w, color: AppColors.success),
          'hall_map_legend_node',
        ),
        item(dot(colors.error), 'hall_map_legend_alert'),
        item(dot(Colors.orange.shade700), 'hall_map_legend_device'),
        item(
          Container(
            width: 14.w,
            height: 14.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.outline),
            ),
          ),
          'hall_map_legend_area',
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onTap});

  final LocatedDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final r = device.result;
    final color = device.isAlert ? colors.error : Colors.orange.shade700;
    return Card(
      margin: EdgeInsets.only(bottom: AppDimens.spacingSmall),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        key: Key('hall_map_device_${device.device.id}'),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Text(
            r.seat,
            style: textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          device.device.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            'hall_map_near_seat'.tr(
              args: {'seat': r.seat, 'm': _metres(r.radius)},
            ),
            'hall_map_heard_by'.tr(
              args: {'count': '${device.readings.length}'},
            ),
          ].join(' · '),
          maxLines: 2,
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: confidenceColor(
              r.confidence,
              colors,
            ).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            _confidenceKey(r.confidence).tr(),
            style: textTheme.labelSmall?.copyWith(
              color: confidenceColor(r.confidence, colors),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceSheet extends StatelessWidget {
  const _DeviceSheet({required this.device});

  final LocatedDevice device;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final r = device.result;
    final d = device.device;
    final notes = 'hall_map_incident_notes'.tr(
      args: {
        'seat': r.seat,
        'm': _metres(r.radius),
        'nodes': device.readings
            .map((x) => '${x.node.name} ≈${x.meters.toStringAsFixed(1)} m')
            .join(', '),
      },
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spacingMedium,
        0,
        AppDimens.spacingMedium,
        AppDimens.spacingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.displayName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      d.deviceType,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'close'.tr(),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          SizedBox(height: AppDimens.spacingSmall),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppDimens.spacingSmall),
            decoration: BoxDecoration(
              color: (device.isAlert ? colors.error : colors.primary)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'hall_map_likely_seat'.tr(args: {'seat': r.seat}),
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'hall_map_within'.tr(args: {'m': _metres(r.radius)}),
                  style: textTheme.bodySmall,
                ),
                SizedBox(height: 4.h),
                Text(
                  _confidenceKey(r.confidence).tr(),
                  style: textTheme.labelMedium?.copyWith(
                    color: confidenceColor(r.confidence, colors),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppDimens.spacingSmall),
          Text(
            'hall_map_readings'.tr(),
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          for (final x in device.readings)
            Padding(
              padding: EdgeInsets.only(top: 6.h),
              child: Row(
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    size: 18.w,
                    color: AppColors.success,
                  ),
                  SizedBox(width: AppDimens.spacingSmall),
                  Expanded(
                    child: Text(
                      x.node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '≈ ${x.meters.toStringAsFixed(1)} m · ${x.rssi} dBm',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: AppDimens.spacingMedium),
          FilledButton.icon(
            key: const Key('hall_map_log'),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(AppDimens.buttonHeight),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              context.pushTo(
                AppRoute.actionNew,
                extra: ActionEntryArgs(device: d, seat: r.seat, notes: notes),
              );
            },
            icon: const Icon(Icons.report_rounded),
            label: Text('hall_map_log'.tr(args: {'seat': r.seat})),
          ),
          // Nodes report MAC addresses; only Android sees those too (iOS
          // gives each device its own UUID), so the radar can follow it.
          if (d.isBle && defaultTargetPlatform == TargetPlatform.android) ...[
            SizedBox(height: AppDimens.spacingExtraSmall),
            OutlinedButton.icon(
              key: const Key('hall_map_track'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(AppDimens.buttonHeight),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                context.pushTo(AppRoute.radar, extra: d);
              },
              icon: const Icon(Icons.radar_rounded),
              label: Text('hall_map_track'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown until the exam has a seat layout: the map needs rows × columns.
class _LayoutForm extends HookWidget {
  const _LayoutForm({required this.onSave});

  final Future<String?> Function(String rows, String cols) onSave;

  @override
  Widget build(BuildContext context) {
    final rows = useTextEditingController();
    final cols = useTextEditingController();
    final error = useState<String?>(null);
    final busy = useState(false);
    final textTheme = Theme.of(context).textTheme;

    Future<void> save() async {
      busy.value = true;
      final problem = await onSave(rows.text, cols.text);
      if (!context.mounted) return;
      busy.value = false;
      error.value = problem;
    }

    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
    );

    return Card(
      key: const Key('hall_map_layout_form'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'hall_map_layout_title'.tr(),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text('hall_map_layout_text'.tr(), style: textTheme.bodySmall),
            SizedBox(height: AppDimens.spacingSmall),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('hall_map_rows'),
                    controller: rows,
                    contextMenuBuilder: appTextContextMenu,
                    keyboardType: TextInputType.number,
                    decoration: deco('setup_seat_rows'.tr()),
                  ),
                ),
                SizedBox(width: AppDimens.spacingSmall),
                Expanded(
                  child: TextField(
                    key: const Key('hall_map_cols'),
                    controller: cols,
                    contextMenuBuilder: appTextContextMenu,
                    keyboardType: TextInputType.number,
                    decoration: deco('setup_seat_cols'.tr()),
                  ),
                ),
              ],
            ),
            if (error.value != null) ...[
              SizedBox(height: 6.h),
              Text(
                error.value!.tr(args: {'min': '1', 'max': '30'}),
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            SizedBox(height: AppDimens.spacingSmall),
            FilledButton(
              key: const Key('hall_map_layout_save'),
              onPressed: busy.value ? null : save,
              child: Text('sweep_layout_set'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
