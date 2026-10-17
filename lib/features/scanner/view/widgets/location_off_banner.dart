import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

/// Android returns no BLE results while Location is off. Explains that and
/// offers a shortcut to the Location settings.
class LocationOffBanner extends StatelessWidget {
  const LocationOffBanner({super.key, required this.onTurnOn});

  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.errorContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_off_rounded,
                  color: scheme.onErrorContainer,
                  size: 24.w,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'scan_location_off_title'.tr(),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'scan_location_off_message'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  minimumSize: const Size(0, 40),
                ),
                onPressed: onTurnOn,
                icon: const Icon(Icons.location_on_rounded, size: 18),
                label: Text('scan_location_turn_on'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
