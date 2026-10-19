import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/features/radar/view/widgets/radar_sizes.dart';

/// Sticky bottom actions: "Find the seat" (BLE only) as the primary and
/// "Log incident" as the secondary; large touch targets, safe-area aware.
class RadarActionBar extends StatelessWidget {
  const RadarActionBar({
    super.key,
    required this.onFindSeat,
    required this.onLogIncident,
  });

  /// Null hides "Find the seat" (seat sweep needs live BLE packets).
  final VoidCallback? onFindSeat;
  final VoidCallback onLogIncident;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = 52.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
    );
    final log = onFindSeat == null
        ? FilledButton.icon(
            key: const Key('radar_log_incident'),
            onPressed: onLogIncident,
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(height),
              shape: shape,
            ),
            icon: const Icon(Icons.report_rounded),
            label: _Label('log_incident'.tr()),
          )
        : OutlinedButton.icon(
            key: const Key('radar_log_incident'),
            onPressed: onLogIncident,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(height),
              shape: shape,
              side: BorderSide(color: colors.outline),
            ),
            icon: const Icon(Icons.report_outlined),
            label: _Label('log_incident'.tr()),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimens.spacingMedium,
            10.rc,
            AppDimens.spacingMedium,
            10.rc,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Row(
                children: [
                  Expanded(child: log),
                  if (onFindSeat != null) ...[
                    SizedBox(width: AppDimens.spacingSmall),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('radar_find_seat'),
                        onPressed: onFindSeat,
                        style: FilledButton.styleFrom(
                          minimumSize: Size.fromHeight(height),
                          shape: shape,
                        ),
                        icon: const Icon(Icons.event_seat_rounded),
                        label: _Label('radar_find_seat'.tr()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 2,
    textAlign: TextAlign.center,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontWeight: FontWeight.w700, height: 1.15),
  );
}
