import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../session/application/session_provider.dart';

class ActionEntryScreen extends HookConsumerWidget {
  const ActionEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceName = useTextEditingController();
    final deviceId = useTextEditingController();
    final location = useTextEditingController();
    final notes = useTextEditingController();
    final saved = useState(false);
    return Scaffold(
      appBar: AppBar(
        title: Text('log_action'.tr()),
        actions: const [AppSettingsMenu()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppDimens.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'log_intro'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(height: AppDimens.spacingLarge),
                  CustomTextField(
                    hintText: 'device_name'.tr(),
                    controller: deviceName,
                    prefixIcon: const Icon(Icons.devices_other_outlined),
                  ),
                  SizedBox(height: AppDimens.spacingMedium),
                  CustomTextField(
                    hintText: 'device_id'.tr(),
                    controller: deviceId,
                    prefixIcon: const Icon(Icons.qr_code_outlined),
                  ),
                  SizedBox(height: AppDimens.spacingMedium),
                  CustomTextField(
                    hintText: 'location'.tr(),
                    controller: location,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                  SizedBox(height: AppDimens.spacingMedium),
                  CustomTextField(
                    hintText: 'notes'.tr(),
                    controller: notes,
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                  SizedBox(height: AppDimens.spacingLarge),
                  PrimaryButton(
                    label: saved.value ? 'saved'.tr() : 'save_record'.tr(),
                    onPressed: () async {
                      await ref.read(sessionProvider.notifier).addLog({
                        'name': deviceName.text.trim(),
                        'id': deviceId.text.trim(),
                        'location': location.text.trim(),
                        'notes': notes.text.trim(),
                        'createdAt': DateTime.now().millisecondsSinceEpoch,
                      });
                      saved.value = true;
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('saved'.tr())));
                      }
                    },
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
