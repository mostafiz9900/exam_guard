import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/services/report/violation_report_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../scanner/domain/scanned_device_model.dart';
import '../../session/application/session_provider.dart';

class ActionEntryScreen extends HookConsumerWidget {
  const ActionEntryScreen({super.key, this.initialDevice});

  final ScannedDeviceModel? initialDevice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceName = useTextEditingController(text: initialDevice?.name ?? '');
    final deviceId = useTextEditingController(text: initialDevice?.id ?? '');
    final location = useTextEditingController();
    final notes = useTextEditingController();

    final selectedType = useState('Bluetooth Device');
    final selectedSeverity = useState('HIGH');
    final isSaving = useState(false);

    final session = ref.watch(sessionProvider).value;

    void showExportReportModal() {
      final textReport = ViolationReportService.instance.generateTextReport(
        device: initialDevice,
        session: session,
        candidateSeat: location.text.trim(),
        inspectorNotes: notes.text.trim(),
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
                      'Official Violation Incident Report',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
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
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusMedium),
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
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: textReport));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Report generated & copied ready for PDF print!',
                              ),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Print / Share Report'),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'All recorded logs are timestamped and appended to the current exam session audit trail.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
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
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusMedium),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: 6.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].map((sev) {
                        final isSelected = selectedSeverity.value == sev;
                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: ChoiceChip(
                            label: Text(sev),
                            selected: isSelected,
                            selectedColor: sev == 'CRITICAL'
                                ? AppColors.error.withValues(alpha: 0.2)
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
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
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Preview PDF Report'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: PrimaryButton(
                          label: isSaving.value ? 'Saving...' : 'Save Audit Record',
                          isLoading: isSaving.value,
                          onPressed: () async {
                            if (deviceName.text.trim().isEmpty &&
                                location.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please provide device name or desk location'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            isSaving.value = true;
                            try {
                              await ref.read(sessionProvider.notifier).addLog({
                                'name': deviceName.text.trim().isEmpty
                                    ? 'Unknown Device'
                                    : deviceName.text.trim(),
                                'id': deviceId.text.trim().isEmpty
                                    ? 'N/A'
                                    : deviceId.text.trim(),
                                'type': selectedType.value,
                                'severity': selectedSeverity.value,
                                'location': location.text.trim().isEmpty
                                    ? 'Unspecified Desk'
                                    : location.text.trim(),
                                'notes': notes.text.trim(),
                                'createdAt': DateTime.now().millisecondsSinceEpoch,
                              });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Violation incident logged successfully'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                context.pop();
                              }
                            } finally {
                              isSaving.value = false;
                            }
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
