import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/widgets/app_text_context_menu.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/custom_text_field.dart';
import 'package:exam_guard/core/widgets/primary_button.dart';
import 'package:exam_guard/features/action_log/model/action_entry_args.dart';
import 'package:exam_guard/features/action_log/model/incident_categories.dart';
import 'package:exam_guard/features/action_log/view/widgets/photo_evidence_section.dart';
import 'package:exam_guard/features/action_log/view/widgets/seat_picker_sheet.dart';
import 'package:exam_guard/features/action_log/view_model/action_entry_view_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/localization/app_localization.dart';

/// Incident categories offered in the form: stored value → label key.
const _categories = IncidentCategory.labelKeys;

/// Display label of a severity; the stored code stays English.
String _severityLabel(LogSeverity severity) => switch (severity) {
  LogSeverity.critical => 'incident_severity_critical'.tr(),
  LogSeverity.high => 'incident_severity_high'.tr(),
  LogSeverity.medium => 'incident_severity_medium'.tr(),
  LogSeverity.low => 'incident_severity_low'.tr(),
};

/// What the user picked in the "incident saved" sheet.
enum _SheetAction { share, done }

/// Global rect of [context]'s widget, used to anchor the iPad share popover.
Rect? _originOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class ActionEntryScreen extends HookConsumerWidget {
  const ActionEntryScreen({super.key, required this.args});

  final ActionEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final deviceName = useTextEditingController(
      text: args.device?.displayName ?? '',
    );
    final deviceId = useTextEditingController(text: args.device?.id ?? '');
    final location = useTextEditingController();
    final notes = useTextEditingController(text: args.notes ?? '');

    final initialCategory = IncidentCategory.initial(
      category: args.category,
      device: args.device,
    );
    final selectedType = useState(initialCategory);
    final selectedSeverity = useState(LogSeverity.high);
    final seat = useState<String?>(null);
    final viewModel = ref.read(actionEntryViewModelProvider.notifier);
    final entryState = ref.watch(actionEntryViewModelProvider);
    final isSaving = entryState.isSaving;
    final seatLayout = viewModel.seatLayout;

    // A category passed in by a scanner is offered even if it is not listed
    // (shown as passed, since it has no translation).
    final categories = {
      for (final c in _categories.entries) c.key: c.value.tr(),
      if (!_categories.containsKey(initialCategory))
        initialCategory: initialCategory,
    };

    void showSnack(ScaffoldMessengerState messenger, String text, Color? bg) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    /// Shows the saved incident's report with copy/share actions.
    Future<void> showSavedReportSheet(ActionLogModel saved) async {
      final textReport = viewModel.textReport(
        saved,
        scannedDevice: args.device,
      );
      // The screen's messenger outlives the sheet and this screen.
      final messenger = ScaffoldMessenger.of(context);

      final result = await showModalBottomSheet<(_SheetAction, Rect?)>(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusLarge),
          ),
        ),
        builder: (sheetContext) => _SavedReportSheet(
          textReport: textReport,
          onCopy: () => viewModel.copyReport(textReport),
        ),
      );

      if (result?.$1 == _SheetAction.share && context.mounted) {
        final message = await viewModel.shareReport(
          textReport,
          origin: result!.$2,
        );
        if (message != null) {
          showSnack(messenger, message.tr(), AppColors.error);
        }
      }
      if (context.mounted) context.popBack();
    }

    Future<void> submit({required bool thenShare}) async {
      final messenger = ScaffoldMessenger.of(context);
      final result = await viewModel.save(
        deviceName: deviceName.text,
        deviceId: deviceId.text,
        category: selectedType.value,
        severity: selectedSeverity.value,
        location: location.text,
        notes: notes.text,
        seat: seatLayout == null ? null : seat.value,
      );
      if (!context.mounted) return;

      switch (result.status) {
        case ActionSaveStatus.busy:
          return;
        case ActionSaveStatus.invalid:
          showSnack(messenger, result.message!.tr(), null);
        case ActionSaveStatus.sessionEnded:
        case ActionSaveStatus.failed:
          showSnack(messenger, result.message!.tr(), AppColors.error);
        case ActionSaveStatus.saved:
          if (thenShare) {
            await showSavedReportSheet(result.log!);
          } else {
            showSnack(messenger, result.message!.tr(), AppColors.success);
            context.popBack();
          }
      }
    }

    Future<void> pickSeat() async {
      final layout = seatLayout;
      if (layout == null) return;
      final picked = await showSeatPickerSheet(
        context,
        rows: layout.rows,
        cols: layout.cols,
        summaries: viewModel.seatSummaries,
        selected: seat.value,
      );
      if (picked != null) seat.value = picked;
    }

    Future<void> addPhoto() async {
      final messenger = ScaffoldMessenger.of(context);
      final message = await viewModel.addPhoto();
      if (message != null) {
        showSnack(
          messenger,
          message.tr(args: {'max': '${ActionEntryViewModel.maxPhotos}'}),
          message == 'incident_photo_limit' ? null : AppColors.error,
        );
      }
    }

    /// Leaving with photos discards them; ask first.
    Future<void> confirmLeave() async {
      if (!viewModel.hasUnsavedPhotos) {
        Navigator.of(context).pop();
        return;
      }
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('incident_discard_title'.tr()),
          content: Text('incident_discard_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('incident_keep_editing'.tr()),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('incident_discard_confirm'.tr()),
            ),
          ],
        ),
      );
      // The view model deletes the photos when the screen is disposed.
      if (leave == true && context.mounted) Navigator.of(context).pop();
    }

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      borderSide: BorderSide(color: colors.outline, width: 1.w),
    );

    return PopScope(
      canPop: entryState.photoPaths.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeave();
      },
      child: Scaffold(
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
                      'incident_form_title'.tr(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'incident_form_subtitle'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: AppDimens.spacingLarge),

                    // Incident Type Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedType.value,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'incident_category'.tr(),
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusMedium,
                          ),
                        ),
                      ),
                      items: [
                        for (final c in categories.entries)
                          DropdownMenuItem(
                            value: c.key,
                            child: Text(
                              c.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) selectedType.value = val;
                      },
                    ),
                    SizedBox(height: AppDimens.spacingMedium),

                    // Severity Choice Chips
                    Text(
                      'incident_severity_level'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                              label: Text(_severityLabel(sev)),
                              selected: isSelected,
                              selectedColor: sev == LogSeverity.critical
                                  ? AppColors.error.withValues(alpha: 0.2)
                                  : colors.primary.withValues(alpha: 0.2),
                              onSelected: (_) => selectedSeverity.value = sev,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: AppDimens.spacingMedium),

                    CustomTextField(
                      hintText: 'incident_device_name_hint'.tr(),
                      controller: deviceName,
                      prefixIcon: const Icon(Icons.devices_other_outlined),
                    ),
                    SizedBox(height: AppDimens.spacingMedium),

                    CustomTextField(
                      hintText: 'incident_device_id_hint'.tr(),
                      controller: deviceId,
                      prefixIcon: const Icon(Icons.qr_code_outlined),
                    ),
                    SizedBox(height: AppDimens.spacingMedium),

                    if (seatLayout != null) ...[
                      _SeatField(
                        seat: seat.value,
                        onTap: isSaving ? null : pickSeat,
                        onClear: isSaving || seat.value == null
                            ? null
                            : () => seat.value = null,
                      ),
                      SizedBox(height: AppDimens.spacingMedium),
                    ],

                    CustomTextField(
                      hintText: seatLayout == null
                          ? 'incident_location_hint'.tr()
                          : 'incident_location_note_hint'.tr(),
                      controller: location,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    SizedBox(height: AppDimens.spacingMedium),

                    // Multi-line notes (CustomTextField is single-line).
                    TextField(
                      contextMenuBuilder: appTextContextMenu,
                      controller: notes,
                      minLines: 3,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: AppDimens.bodyLarge,
                      ),
                      decoration: InputDecoration(
                        hintText: 'incident_notes_hint'.tr(),
                        hintStyle: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: AppDimens.bodyMedium,
                        ),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: colors.surface,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 40.h),
                          child: Icon(
                            Icons.notes_outlined,
                            color: colors.primary,
                            size: 20.w,
                          ),
                        ),
                        contentPadding: EdgeInsets.all(AppDimens.spacingMedium),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: fieldBorder.copyWith(
                          borderSide: BorderSide(
                            color: colors.primary,
                            width: 1.5.w,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppDimens.spacingMedium),

                    PhotoEvidenceSection(
                      photoPaths: entryState.photoPaths,
                      maxPhotos: ActionEntryViewModel.maxPhotos,
                      isTakingPhoto: entryState.isTakingPhoto,
                      enabled: !isSaving,
                      onAdd: addPhoto,
                      onRemove: viewModel.removePhoto,
                    ),
                    SizedBox(height: AppDimens.spacingLarge),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () => submit(thenShare: true),
                            icon: const Icon(Icons.description_rounded),
                            label: Text('incident_save_share'.tr()),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: PrimaryButton(
                            label: isSaving
                                ? 'incident_saving'.tr()
                                : 'save_record'.tr(),
                            isLoading: isSaving,
                            onPressed: () => submit(thenShare: false),
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
      ),
    );
  }
}

/// Read-only field that opens the seat map; shows the chosen seat.
class _SeatField extends StatelessWidget {
  const _SeatField({required this.seat, this.onTap, this.onClear});

  final String? seat;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      borderSide: BorderSide(color: colors.outline, width: 1.w),
    );
    final hasSeat = seat != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: InputDecorator(
        isEmpty: !hasSeat,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: colors.surface,
          labelText: 'incident_seat'.tr(),
          hintText: 'incident_seat_pick'.tr(),
          prefixIcon: Icon(
            Icons.event_seat_outlined,
            color: colors.primary,
            size: 20.w,
          ),
          suffixIcon: hasSeat
              ? IconButton(
                  tooltip: 'incident_seat_clear'.tr(),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                )
              : Icon(Icons.grid_view_rounded, color: colors.onSurfaceVariant),
          border: border,
          enabledBorder: border,
        ),
        child: hasSeat
            ? Text(
                seat!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              )
            : null,
      ),
    );
  }
}

/// Report of an incident that is already saved. Copy feedback is shown
/// inside the sheet (a SnackBar would be hidden behind it); Share and Done
/// close the sheet and the screen handles them.
class _SavedReportSheet extends HookWidget {
  const _SavedReportSheet({required this.textReport, required this.onCopy});

  final String textReport;
  final Future<bool> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final copyStatus = useState<bool?>(null);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 24.w,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'incident_sheet_title'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    textReport,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.sp,
                      color: colors.onSurface,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
            if (copyStatus.value != null) ...[
              SizedBox(height: 8.h),
              Text(
                copyStatus.value!
                    ? 'incident_copy_done'.tr()
                    : 'incident_copy_failed'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: copyStatus.value! ? AppColors.success : colors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await onCopy();
                      if (context.mounted) copyStatus.value = ok;
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text('incident_copy_text'.tr()),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Builder(
                    builder: (buttonContext) => ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                      ),
                      onPressed: () => Navigator.of(context)
                          .pop((_SheetAction.share, _originOf(buttonContext))),
                      icon: const Icon(Icons.share_rounded),
                      label: Text('incident_share'.tr()),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pop((_SheetAction.done, null)),
                child: Text('incident_done'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
