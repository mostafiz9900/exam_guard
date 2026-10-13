import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/custom_text_field.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/action_log/view_model/action_entry_view_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/localization/app_localization.dart';

class ActionEntryScreen extends HookConsumerWidget {
  const ActionEntryScreen({super.key, required this.args});

  final ActionEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceName = useTextEditingController(
      text: args.device?.name ?? '',
    );
    final deviceId = useTextEditingController(text: args.device?.id ?? '');
    final location = useTextEditingController();
    final notes = useTextEditingController();

    final selectedType = useState('Bluetooth Device');
    final selectedSeverity = useState(LogSeverity.high);
    final viewModel = ref.read(actionEntryViewModelProvider.notifier);
    final isSaving = ref.watch(actionEntryViewModelProvider).isSaving;

    ActionLogModel currentLog() => viewModel.buildLog(
      deviceName: deviceName.text,
      deviceId: deviceId.text,
      category: selectedType.value,
      severity: selectedSeverity.value,
      location: location.text,
      notes: notes.text,
    );

    void showExportReportModal() {
      final textReport = viewModel.textReport(
        currentLog(),
        scannedDevice: args.device,
      );

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusLarge),
          ),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.all(AppDimens.spacingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.red,
                      size: 24.w,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Violation Incident Report',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 20),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 280.h),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusMedium,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        textReport,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10.sp,
                          color: Colors.greenAccent.shade200,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: textReport));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report text copied to clipboard!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy Report Text'),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          final message = await viewModel.shareReport(
                            textReport,
                          );
                          if (message != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(message),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Share Report'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('log_action'.tr()),
        actions: const [AppSettingsMenu()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppDimens.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Record Malpractice / Technical Violation Incident',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'All recorded logs are timestamped and appended to the current exam session audit trail.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                  SizedBox(height: AppDimens.spacingLarge),

                  // Incident Type Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedType.value,
                    decoration: InputDecoration(
                      labelText: 'Incident Category',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusMedium,
                        ),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Bluetooth Device',
                        child: Text('Bluetooth / BLE Device'),
                      ),
                      DropdownMenuItem(
                        value: 'Active Cellular SIM Call',
                        child: Text('Active SIM / GSM Voice Call 📞'),
                      ),
                      DropdownMenuItem(
                        value: 'Online VoIP Call',
                        child: Text('Online Call (WhatsApp / IMO) 🌐'),
                      ),
                      DropdownMenuItem(
                        value: 'Mobile 4G/5G Data Usage',
                        child: Text('Mobile 4G / 5G Data Transmission 📶'),
                      ),
                      DropdownMenuItem(
                        value: 'Magnetic Anomaly',
                        child: Text('Magnetic / EMP Anomaly'),
                      ),
                      DropdownMenuItem(
                        value: 'Suspicious Activity',
                        child: Text('Suspicious Electronic Activity'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) selectedType.value = val;
                    },
                  ),
                  SizedBox(height: AppDimens.spacingMedium),

                  // Severity Choice Chips
                  Text(
                    'Severity Level',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: LogSeverity.values.map((sev) {
                        final isSelected = selectedSeverity.value == sev;
                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: ChoiceChip(
                            label: Text(sev.code),
                            selected: isSelected,
                            selectedColor: sev == LogSeverity.critical
                                ? AppColors.error.withValues(alpha: 0.2)
                                : Theme.of(context).colorScheme.primary
                                      .withValues(alpha: 0.2),
                            onSelected: (_) => selectedSeverity.value = sev,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: AppDimens.spacingMedium),

                  CustomTextField(
                    hintText: 'Device / Threat Name',
                    controller: deviceName,
                    prefixIcon: const Icon(Icons.devices_other_outlined),
                  ),
                  SizedBox(height: AppDimens.spacingMedium),

                  CustomTextField(
                    hintText: 'MAC ID / Serial Number (Optional)',
                    controller: deviceId,
                    prefixIcon: const Icon(Icons.qr_code_outlined),
                  ),
                  SizedBox(height: AppDimens.spacingMedium),

                  CustomTextField(
                    hintText: 'Location / Desk / Seat Number',
                    controller: location,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                  SizedBox(height: AppDimens.spacingMedium),

                  CustomTextField(
                    hintText: 'Inspector Notes / Comments',
                    controller: notes,
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                  SizedBox(height: AppDimens.spacingLarge),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: showExportReportModal,
                          icon: const Icon(Icons.description_rounded),
                          label: const Text('Preview Report'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: PrimaryButton(
                          label: isSaving ? 'Saving...' : 'Save Audit Record',
                          isLoading: isSaving,
                          onPressed: () async {
                            final error = viewModel.validate(
                              deviceName: deviceName.text,
                              location: location.text,
                            );
                            if (error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            final saved = await viewModel.save(currentLog());
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  saved
                                      ? 'Violation incident logged successfully'
                                      : 'Could not save the incident. Try again.',
                                ),
                                backgroundColor: saved
                                    ? AppColors.success
                                    : AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            if (saved) context.popBack();
                          },
                        ),
                      ),
                    ],
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
