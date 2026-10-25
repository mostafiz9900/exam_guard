import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_qr_image.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';

/// Host only: the QR code other invigilators scan, plus the address and
/// code for typing it in when a camera can't read it.
class HallInviteCard extends StatelessWidget {
  const HallInviteCard({super.key, required this.invite});

  final HallInvite invite;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final address = '${invite.host}:${invite.port}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingMedium),
        child: Column(
          children: [
            Text(
              'hall_scan_to_join'.tr(),
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppDimens.spacingSmall),
            LayoutBuilder(
              builder: (context, c) => ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                child: AppQrImage(
                  data: invite.encode(),
                  size: c.maxWidth.clamp(120, 260).toDouble(),
                ),
              ),
            ),
            SizedBox(height: AppDimens.spacingSmall),
            SelectableText(
              'hall_address'.tr(args: {'address': address}),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            InkWell(
              onTap: () => Clipboard.setData(ClipboardData(text: invite.token)),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Text(
                  'hall_code'.tr(args: {'code': invite.token}),
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'hall_trust_hint'.tr(),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
