import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/widgets/app_text_context_menu.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/action_log/model/seat_map.dart';
import 'package:exam_guard/features/radar/model/seat_sweep_models.dart';
import 'package:exam_guard/features/radar/view/widgets/finder_issue_banner.dart';
import 'package:exam_guard/features/radar/view/widgets/closeness_colors.dart';
import 'package:exam_guard/features/radar/view_model/seat_sweep_view_model.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// Seat sweep: sample the target's signal seat by seat on the room's seat
/// map; the strongest seat is the most likely hiding place.
class SeatSweepScreen extends HookConsumerWidget {
  const SeatSweepScreen({super.key, this.targetDevice});

  final ScannedDeviceModel? targetDevice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(seatSweepViewModelProvider);
    final notifier = ref.read(seatSweepViewModelProvider.notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    useEffect(() {
      final device = targetDevice;
      if (device != null) Future.microtask(() => notifier.setTarget(device));
      return null;
    }, [targetDevice]);

    // Re-render once a second so "live" turns into "not heard" when the
    // target goes silent.
    final clock = useState(DateTime.now());
    useEffect(() {
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => clock.value = DateTime.now(),
      );
      return timer.cancel;
    }, const []);

    final device = state.device ?? targetDevice;
    final result = state.result;

    Future<void> confirmClear() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('sweep_clear_title'.tr()),
          content: Text('sweep_clear_text'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('sweep_cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('sweep_clear'.tr()),
            ),
          ],
        ),
      );
      if (ok == true) notifier.clearAll();
    }

    Future<void> logIncident(ScannedDeviceModel device) async {
      await context.pushTo(
        AppRoute.actionNew,
        extra: ActionEntryArgs(
          device: device,
          category: 'Bluetooth Device',
          notes: notifier.incidentNotes(),
        ),
      );
    }

    final Widget body;
    if (device == null || !device.isBle) {
      body = _Message(
        icon: Icons.bluetooth_disabled_rounded,
        title: 'sweep_no_target_title'.tr(),
        text: 'sweep_no_target_text'.tr(),
        onBack: () => context.popBack(),
      );
    } else if (!state.hasLayout) {
      body = _SeatLayoutForm(
        errorKey: state.layoutErrorKey,
        isSaving: state.isSavingLayout,
        onChanged: notifier.clearLayoutError,
        onSave: notifier.saveSeatLayout,
        onBack: () => context.popBack(),
      );
    } else {
      final lastHeard = state.lastHeard;
      final live =
          lastHeard != null &&
          clock.value.difference(lastHeard) < const Duration(seconds: 5) &&
          state.liveRssi != null;
      body = ListView(
        padding: EdgeInsets.all(AppDimens.spacingMedium),
        children: [
          Text(
            device.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Icon(
                live
                    ? Icons.bluetooth_audio_rounded
                    : Icons.bluetooth_searching_rounded,
                size: 16.w,
                color: live ? colors.primary : colors.outline,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  live
                      ? 'sweep_live_signal'.tr(
                          args: {'rssi': '${state.liveRssi!.round()}'},
                        )
                      : 'sweep_not_heard'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimens.spacingSmall),
          if (state.issue != null) ...[
            FinderIssueBanner(
              issue: state.issue!,
              onOpenLocation: notifier.openLocationSettings,
              onTurnOnBluetooth: notifier.turnOnBluetooth,
              onRetry: notifier.retry,
            ),
            SizedBox(height: AppDimens.spacingSmall),
          ],
          Text(
            'sweep_instructions'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: AppDimens.spacingSmall),
          if (state.samplingSeat != null)
            _SamplingPanel(
              seat: state.samplingSeat!,
              progress: state.samplingProgress,
              packets: state.samplingPackets,
              onCancel: notifier.cancelSampling,
            )
          else if (state.isNotHeard && state.issue == null)
            _Notice(
              key: const Key('sweep_not_heard_hint'),
              text: 'sweep_not_heard_hint'.tr(),
              isWarning: true,
            )
          else if (state.noSignalSeat != null)
            _Notice(
              text: 'sweep_no_signal_here'.tr(
                args: {
                  'seat': state.noSignalSeat!,
                  'min': '${SeatSampler.minPackets}',
                },
              ),
            ),
          SizedBox(height: AppDimens.spacingSmall),
          _SeatGrid(
            rows: state.rows,
            cols: state.cols,
            readings: state.readings,
            samplingSeat: state.samplingSeat,
            bestSeat: result?.bestSeat,
            enabled:
                state.issue == null &&
                state.samplingSeat == null &&
                !state.isNotHeard,
            onTap: notifier.sampleSeat,
            onLongPress: notifier.clearSeat,
          ),
          SizedBox(height: AppDimens.spacingMedium),
          _ResultCard(result: result),
          SizedBox(height: AppDimens.spacingMedium),
          PrimaryButton(
            label: result == null
                ? 'log_incident'.tr()
                : 'sweep_log_at_seat'.tr(args: {'seat': result.bestSeat}),
            onPressed: result == null ? null : () => logIncident(device),
          ),
          SizedBox(height: 4.h),
          Text(
            'sweep_honest'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 10.sp,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('sweep_title'.tr()),
        actions: [
          if (state.readings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'sweep_clear'.tr(),
              onPressed: confirmClear,
            ),
          const AppSettingsMenu(),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _SeatGrid extends StatelessWidget {
  const _SeatGrid({
    required this.rows,
    required this.cols,
    required this.readings,
    required this.samplingSeat,
    required this.bestSeat,
    required this.enabled,
    required this.onTap,
    required this.onLongPress,
  });

  final int rows;
  final int cols;
  final Map<String, SeatReading> readings;
  final String? samplingSeat;
  final String? bestSeat;
  final bool enabled;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cell = 52.w;
    final labelWidth = 28.w;

    // Colour relative to the sampled range so a few dB stand out.
    final values = [
      for (final r in readings.values)
        if (r.averageRssi != null) r.averageRssi!,
    ];
    final minRssi = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a < b ? a : b);
    final maxRssi = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    int heat(double rssi) {
      if (maxRssi - minRssi < 1) return 60;
      return ((rssi - minRssi) / (maxRssi - minRssi) * 100).round();
    }

    final gridWidth = labelWidth + cols * (cell + 4);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: gridWidth,
            padding: EdgeInsets.symmetric(vertical: 6.h),
            margin: EdgeInsets.only(bottom: 6.h),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              'sweep_front'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Row(
            children: [
              SizedBox(width: labelWidth),
              for (var c = 0; c < cols; c++)
                SizedBox(
                  width: cell + 4,
                  child: Text(
                    SeatId.colLabel(c),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
            ],
          ),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    SeatId.rowLabel(r),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (var c = 0; c < cols; c++)
                  _seat(context, SeatId.format(r, c), cell, heat),
              ],
            ),
        ],
      ),
    );
  }

  Widget _seat(
    BuildContext context,
    String seat,
    double size,
    int Function(double) heat,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reading = readings[seat];
    final isSampling = seat == samplingSeat;
    final isBest = seat == bestSeat;
    final rssi = reading?.averageRssi;

    final Color fill;
    final Color textColor;
    if (rssi != null) {
      fill = closenessColor(heat(rssi));
      textColor = Colors.white;
    } else if (reading != null) {
      fill = colors.outline.withValues(alpha: 0.35);
      textColor = colors.onSurface;
    } else {
      fill = colors.surfaceContainerHighest;
      textColor = colors.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
          side: isBest
              ? BorderSide(color: colors.onSurface, width: 3)
              : isSampling
              ? BorderSide(color: colors.primary, width: 3)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => onTap(seat) : null,
          onLongPress: enabled && reading != null
              ? () => onLongPress(seat)
              : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBest)
                      Icon(Icons.star_rounded, size: 12.w, color: textColor),
                    Text(
                      seat,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (isSampling)
                  SizedBox(
                    width: 14.w,
                    height: 14.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (reading != null)
                  Text(
                    rssi == null ? '✕' : '${rssi.round()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: textColor,
                      fontFamily: 'monospace',
                      fontSize: 10.sp,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SamplingPanel extends StatelessWidget {
  const _SamplingPanel({
    required this.seat,
    required this.progress,
    required this.packets,
    required this.onCancel,
  });

  final String seat;
  final double progress;
  final int packets;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'sweep_sampling'.tr(
                      args: {'seat': seat, 'packets': '$packets'},
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onCancel,
                  child: Text('sweep_cancel'.tr()),
                ),
              ],
            ),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8.h,
            ),
            SizedBox(height: 4.h),
            Text('sweep_hold_still'.tr(), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final SeatSweepResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final r = result;
    if (r == null) {
      return _Notice(text: 'sweep_no_result'.tr());
    }
    final confidenceColor = switch (r.confidence) {
      SweepConfidence.high => const Color(0xFF22C55E),
      SweepConfidence.medium => const Color(0xFFF59E0B),
      SweepConfidence.low => colors.outline,
    };
    final second = r.secondSeat;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(color: confidenceColor, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'sweep_most_likely'.tr(
                args: {'seat': r.bestSeat, 'rssi': '${r.bestRssi.round()}'},
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(Icons.insights_rounded, color: confidenceColor),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    r.confidence.labelKey.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: confidenceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              second == null
                  ? 'sweep_only_one_seat'.tr()
                  : 'sweep_margin'.tr(
                      args: {
                        'margin': r.marginDb!.toStringAsFixed(1),
                        'seat': second,
                        'rssi': '${r.secondRssi!.round()}',
                      },
                    ),
              style: theme.textTheme.bodySmall,
            ),
            if (r.confidence == SweepConfidence.low) ...[
              SizedBox(height: 4.h),
              Text(
                'sweep_sample_neighbours'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, this.isWarning = false});

  final String text;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(AppDimens.spacingSmall),
      decoration: BoxDecoration(
        color: isWarning
            ? colors.errorContainer.withValues(alpha: 0.5)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(
            isWarning
                ? Icons.bluetooth_searching_rounded
                : Icons.info_outline_rounded,
            size: 18.w,
            color: isWarning ? colors.error : colors.outline,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    required this.onBack,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56.w, color: theme.colorScheme.outline),
            SizedBox(height: 12.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            SizedBox(height: 8.h),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 16.h),
            OutlinedButton(onPressed: onBack, child: Text('walk_go_back'.tr())),
          ],
        ),
      ),
    );
  }
}

/// The running exam has no seat layout: enter rows × columns here (saved
/// to the exam) instead of leaving the screen.
class _SeatLayoutForm extends HookWidget {
  const _SeatLayoutForm({
    required this.errorKey,
    required this.isSaving,
    required this.onChanged,
    required this.onSave,
    required this.onBack,
  });

  final String? errorKey;
  final bool isSaving;
  final VoidCallback onChanged;
  final Future<bool> Function(String rows, String cols) onSave;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rows = useTextEditingController();
    final cols = useTextEditingController();
    final error = errorKey?.tr(
      args: {'min': '${SeatLayoutDraft.min}', 'max': '${SeatLayoutDraft.max}'},
    );

    Future<void> save() async {
      FocusScope.of(context).unfocus();
      await onSave(rows.text, cols.text);
    }

    Widget field(TextEditingController c, String label, String hint, Key key) =>
        Expanded(
          child: TextField(
            contextMenuBuilder: appTextContextMenu,
            key: key,
            controller: c,
            enabled: !isSaving,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            textAlign: TextAlign.center,
            maxLength: 2,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => save(),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              isDense: true,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
            ),
          ),
        );

    return ListView(
      padding: EdgeInsets.all(AppDimens.spacingLarge),
      children: [
        Icon(Icons.grid_view_rounded, size: 56.w, color: colors.outline),
        SizedBox(height: 12.h),
        Text(
          'sweep_no_layout_title'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        SizedBox(height: 8.h),
        Text(
          'sweep_layout_form_text'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            field(
              rows,
              'setup_seat_rows'.tr(),
              '6',
              const Key('sweep_seat_rows'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Text(
                '×',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            field(
              cols,
              'setup_seat_cols'.tr(),
              '5',
              const Key('sweep_seat_cols'),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          error ?? 'sweep_layout_saved_note'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: error != null ? colors.error : colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 16.h),
        FilledButton.icon(
          key: const Key('sweep_layout_save'),
          onPressed: isSaving ? null : save,
          icon: isSaving
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text('sweep_layout_set'.tr()),
        ),
        SizedBox(height: 8.h),
        OutlinedButton(onPressed: onBack, child: Text('walk_go_back'.tr())),
      ],
    );
  }
}
