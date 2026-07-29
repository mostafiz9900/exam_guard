import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';

class MagneticScannerScreen extends StatelessWidget {
  const MagneticScannerScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('magnetic_scanner'.tr()),
      actions: const [AppSettingsMenu()],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: EdgeInsets.all(AppDimens.spacingLarge),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(AppDimens.spacingExtraLarge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sensors_off_outlined,
                    size: 58,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(height: AppDimens.spacingMedium),
                  Text(
                    'sensor_unavailable'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppDimens.spacingSmall),
                  Text(
                    'magnetic_description'.tr(),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
