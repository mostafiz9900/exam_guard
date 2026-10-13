import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/features/action_log/repository/action_log_repository.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

class ActionEntryState {
  const ActionEntryState({this.isSaving = false});

  final bool isSaving;
}

/// Records a violation incident and produces its text report.
class ActionEntryViewModel extends Notifier<ActionEntryState> {
  @override
  ActionEntryState build() => const ActionEntryState();

  /// Returns an error message, or null when the entry can be saved.
  String? validate({required String deviceName, required String location}) {
    if (deviceName.trim().isEmpty && location.trim().isEmpty) {
      return 'Please provide device name or desk location';
    }
    return null;
  }

  ActionLogModel buildLog({
    required String deviceName,
    required String deviceId,
    required String category,
    required LogSeverity severity,
    required String location,
    required String notes,
  }) {
    return ActionLogModel(
      deviceName: deviceName.trim().isEmpty
          ? 'Unknown Device'
          : deviceName.trim(),
      deviceId: deviceId.trim().isEmpty ? 'N/A' : deviceId.trim(),
      category: category,
      severity: severity,
      location: location.trim(),
      notes: notes.trim(),
      createdAt: DateTime.now(),
    );
  }

  String textReport(ActionLogModel log, {ScannedDeviceModel? scannedDevice}) {
    return ref
        .read(actionLogRepositoryProvider)
        .buildTextReport(
          log: log,
          session: ref.read(sessionViewModelProvider),
          scannedDevice: scannedDevice,
        );
  }

  /// Opens the share sheet. Returns a message to show, or null.
  Future<String?> shareReport(String text) async {
    final room = ref.read(sessionViewModelProvider)?.roomNumber ?? '';
    try {
      final outcome = await ref
          .read(actionLogRepositoryProvider)
          .shareReport(
            text,
            subject: 'ExamGuard violation report — Room $room',
          );
      return outcome == ShareOutcome.unavailable
          ? 'Sharing is not available on this device'
          : null;
    } catch (e, st) {
      ref.read(appLoggerProvider).error('Sharing report failed', e, st);
      return 'Could not share the report: $e';
    }
  }

  /// Saves the incident into the current session. Returns false on failure.
  Future<bool> save(ActionLogModel log) async {
    state = const ActionEntryState(isSaving: true);
    try {
      await ref.read(sessionViewModelProvider.notifier).addLog(log);
      return true;
    } catch (e, st) {
      ref.read(appLoggerProvider).error('Saving incident failed', e, st);
      return false;
    } finally {
      if (ref.mounted) state = const ActionEntryState();
    }
  }
}

final actionEntryViewModelProvider =
    NotifierProvider.autoDispose<ActionEntryViewModel, ActionEntryState>(
      ActionEntryViewModel.new,
    );
