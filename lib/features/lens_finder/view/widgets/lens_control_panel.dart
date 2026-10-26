import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/lens_finder/view_model/lens_finder_view_model.dart';

/// Torch, sensitivity, a short how-to and the honest limits of the check.
class LensControlPanel extends StatelessWidget {
  const LensControlPanel({
    super.key,
    required this.state,
    required this.onToggleTorch,
    required this.onSensitivity,
  });

  final LensFinderState state;
  final VoidCallback onToggleTorch;
  final ValueChanged<LensSensitivity> onSensitivity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final canUseCamera =
        state.status != LensFinderStatus.noCamera &&
        state.status != LensFinderStatus.permissionDenied;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Torch
            Row(
              children: [
                Icon(
                  state.isTorchOn
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                  size: 20,
                  color: state.isTorchOn
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'lens_torch'.tr(),
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        state.isTorchAvailable
                            ? 'lens_torch_hint'.tr()
                            : 'lens_torch_unavailable'.tr(),
                        style: text.labelSmall?.copyWith(
                          color: state.isTorchAvailable
                              ? colors.onSurfaceVariant
                              : colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.isTorchOn,
                  onChanged: canUseCamera ? (_) => onToggleTorch() : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'lens_sensitivity'.tr(),
              style: text.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<LensSensitivity>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                for (final s in LensSensitivity.values)
                  ButtonSegment(
                    value: s,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_sensitivityKey(s).tr(), maxLines: 1),
                    ),
                  ),
              ],
              selected: {state.sensitivity},
              onSelectionChanged: (s) => onSensitivity(s.first),
            ),
            const SizedBox(height: 16),
            Text(
              'lens_guide_title'.tr(),
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _Step(
              number: 1,
              icon: Icons.light_mode_outlined,
              title: 'lens_step1_title'.tr(),
              body: 'lens_step1_text'.tr(),
            ),
            _Step(
              number: 2,
              icon: Icons.straighten_rounded,
              title: 'lens_step2_title'.tr(),
              body: 'lens_step2_text'.tr(),
            ),
            _Step(
              number: 3,
              icon: Icons.pan_tool_alt_outlined,
              title: 'lens_step3_title'.tr(),
              body: 'lens_step3_text'.tr(),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.tertiaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 20,
                    color: colors.onTertiaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'lens_disclaimer_title'.tr(),
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'lens_disclaimer_text'.tr(),
                          style: text.bodySmall?.copyWith(
                            color: colors.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sensitivityKey(LensSensitivity s) => switch (s) {
    LensSensitivity.low => 'lens_sens_low',
    LensSensitivity.normal => 'lens_sens_normal',
    LensSensitivity.high => 'lens_sens_high',
  };
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });

  final int number;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: colors.primary.withValues(alpha: 0.15),
            child: Text(
              '$number',
              style: text.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: colors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
