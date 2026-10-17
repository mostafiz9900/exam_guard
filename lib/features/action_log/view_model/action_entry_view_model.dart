import 'package:flutter/services.dart';
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

enum ActionSaveStatus {
  /// The incident is stored in the running exam session.
  saved,

  /// The form is incomplete; nothing was stored.
  invalid,

  /// The exam has ended, so incidents can no longer be added.
  sessionEnded,

  /// Storing failed; the user may retry.
  failed,

  /// A save is already in progress; this call did nothing.
  busy,
}

/// Outcome of [ActionEntryViewModel.save].
class ActionSaveResult {
  const ActionSaveResult._(this.status, {this.message, this.log});

  final ActionSaveStatus status;

  /// Translation key of what to show the user, or null when nothing
  /// should be shown.
  final String? message;

  /// The stored incident (only when [status] is [ActionSaveStatus.saved]).
  final ActionLogModel? log;

  bool get isSaved => status == ActionSaveStatus.saved;
}

/// Records a violation incident and produces its text report.
class ActionEntryViewModel extends Notifier<ActionEntryState> {
  @override
  ActionEntryState build() => const ActionEntryState();

  /// Returns an error message key, or null when the entry can be saved.
  String? validate({required String deviceName, required String location}) {
    if (deviceName.trim().isEmpty && location.trim().isEmpty) {
      return 'incident_err_name_or_location';
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

  /// Text report of a saved incident (uses its own `createdAt`).
  String textReport(ActionLogModel log, {ScannedDeviceModel? scannedDevice}) {
    return ref
        .read(actionLogRepositoryProvider)
        .buildTextReport(
          log: log,
          session: ref.read(sessionViewModelProvider),
          scannedDevice: scannedDevice,
        );
  }

  /// Opens the share sheet. Returns a message key to show, or null.
  /// The subject stays English like the report itself.
  /// [origin] anchors the iPad share popover.
  Future<String?> shareReport(String text, {Rect? origin}) async {
    final room = ref.read(sessionViewModelProvider)?.roomNumber.trim() ?? '';
    try {
      final outcome = await ref
          .read(actionLogRepositoryProvider)
          .shareReport(
            text,
            subject:
                'ExamGuard violation report — Room ${room.isEmpty ? '-' : room}',
            origin: origin,
          );
      return outcome == ShareOutcome.unavailable
          ? 'incident_share_unavailable'
          : null;
    } catch (e, st) {
      ref.read(appLoggerProvider).error('Sharing report failed', e, st);
      return 'incident_share_failed';
    }
  }

  /// Copies [text] to the clipboard. Returns false when copying failed.
  Future<bool> copyReport(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (e, st) {
      ref.read(appLoggerProvider).error('Copying report failed', e, st);
      return false;
    }
  }

  /// Validates the form and saves the incident into the running session.
  Future<ActionSaveResult> save({
    required String deviceName,
    required String deviceId,
    required String category,
    required LogSeverity severity,
    required String location,
    required String notes,
  }) async {
    if (state.isSaving) {
      return const ActionSaveResult._(ActionSaveStatus.busy);
    }
    final error = validate(deviceName: deviceName, location: location);
    if (error != null) {
      return ActionSaveResult._(ActionSaveStatus.invalid, message: error);
    }

    final log = buildLog(
      deviceName: deviceName,
      deviceId: deviceId,
      category: category,
      severity: severity,
      location: location,
      notes: notes,
    );
    state = const ActionEntryState(isSaving: true);
    try {
      await ref.read(sessionViewModelProvider.notifier).addLog(log);
      return ActionSaveResult._(
        ActionSaveStatus.saved,
        message: 'incident_saved',
        log: log,
      );
    } on NoActiveSessionException catch (e) {
      ref.read(appLoggerProvider).warning('Incident not saved: $e');
      return const ActionSaveResult._(
        ActionSaveStatus.sessionEnded,
        message: 'incident_err_session_ended',
      );
    } catch (e, st) {
      ref.read(appLoggerProvider).error('Saving incident failed', e, st);
      return const ActionSaveResult._(
        ActionSaveStatus.failed,
        message: 'incident_err_save_failed',
      );
    } finally {
      if (ref.mounted) state = const ActionEntryState();
    }
  }
}

final actionEntryViewModelProvider =
    NotifierProvider.autoDispose<ActionEntryViewModel, ActionEntryState>(
      ActionEntryViewModel.new,
    );
