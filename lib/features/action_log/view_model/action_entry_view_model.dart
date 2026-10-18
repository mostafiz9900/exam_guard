import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/camera/i_photo_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/features/action_log/model/seat_map.dart';
import 'package:exam_guard/features/action_log/repository/action_log_repository.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

class ActionEntryState {
  const ActionEntryState({
    this.isSaving = false,
    this.isTakingPhoto = false,
    this.photoPaths = const [],
  });

  final bool isSaving;
  final bool isTakingPhoto;

  /// Evidence photos taken for this incident, in order.
  final List<String> photoPaths;

  bool get canAddPhoto =>
      !isTakingPhoto && photoPaths.length < ActionEntryViewModel.maxPhotos;

  ActionEntryState copyWith({
    bool? isSaving,
    bool? isTakingPhoto,
    List<String>? photoPaths,
  }) => ActionEntryState(
    isSaving: isSaving ?? this.isSaving,
    isTakingPhoto: isTakingPhoto ?? this.isTakingPhoto,
    photoPaths: photoPaths ?? this.photoPaths,
  );
}

/// Rows × columns of the running exam's seat map.
typedef SeatLayout = ({int rows, int cols});

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
  /// Most evidence photos one incident can have.
  static const maxPhotos = 4;

  /// Photos taken here that no saved incident owns yet. Deleted when the
  /// form is left without saving, so no orphan files remain.
  List<String> _unsaved = const [];

  @override
  ActionEntryState build() {
    // Read now: `ref` must not be used inside onDispose.
    final repository = ref.read(actionLogRepositoryProvider);
    final logger = ref.read(appLoggerProvider);
    ref.onDispose(() {
      final leftover = _unsaved;
      _unsaved = const [];
      for (final path in leftover) {
        repository.deletePhoto(path).catchError((Object e, StackTrace st) {
          logger.error('Deleting discarded photo failed', e, st);
        });
      }
    });
    return const ActionEntryState();
  }

  /// True while photos would be lost by leaving the form.
  bool get hasUnsavedPhotos => _unsaved.isNotEmpty;

  /// Seat layout of the running exam, or null when it has none.
  SeatLayout? get seatLayout {
    final session = ref.read(sessionViewModelProvider);
    if (session == null || !session.hasSeatLayout) return null;
    return (rows: session.seatRows!, cols: session.seatCols!);
  }

  /// Incidents already recorded per seat in the running exam.
  Map<String, SeatSummary> get seatSummaries =>
      summarizeSeats(ref.read(sessionViewModelProvider)?.deviceLogs ?? []);

  /// Returns an error message key, or null when the entry can be saved:
  /// a seat, a location note or a device name is required.
  String? validate({
    required String deviceName,
    required String location,
    String? seat,
  }) {
    if (deviceName.trim().isEmpty &&
        location.trim().isEmpty &&
        (seat?.trim().isEmpty ?? true)) {
      return 'incident_err_seat_name_or_location';
    }
    return null;
  }

  /// Takes an evidence photo. Returns a message key to show, or null
  /// (photo added, or the user cancelled).
  Future<String?> addPhoto() async {
    if (state.isTakingPhoto || state.isSaving) return null;
    if (state.photoPaths.length >= maxPhotos) return 'incident_photo_limit';

    state = state.copyWith(isTakingPhoto: true);
    final repository = ref.read(actionLogRepositoryProvider);
    try {
      final path = await repository.takePhoto();
      if (!ref.mounted) {
        // The form was closed while the camera was open.
        if (path != null) await repository.deletePhoto(path);
        return null;
      }
      if (path == null) return null;
      _unsaved = [..._unsaved, path];
      state = state.copyWith(photoPaths: [...state.photoPaths, path]);
      return null;
    } on PhotoException catch (e) {
      ref.read(appLoggerProvider).warning('Photo not taken: $e');
      return 'incident_photo_failed';
    } catch (e, st) {
      ref.read(appLoggerProvider).error('Taking photo failed', e, st);
      return 'incident_photo_failed';
    } finally {
      if (ref.mounted) state = state.copyWith(isTakingPhoto: false);
    }
  }

  /// Removes a photo from the form and deletes its file.
  Future<void> removePhoto(String path) async {
    if (state.isSaving || !state.photoPaths.contains(path)) return;
    state = state.copyWith(photoPaths: [...state.photoPaths]..remove(path));
    _unsaved = [..._unsaved]..remove(path);
    try {
      await ref.read(actionLogRepositoryProvider).deletePhoto(path);
    } catch (e, st) {
      ref.read(appLoggerProvider).error('Deleting photo failed', e, st);
    }
  }

  ActionLogModel buildLog({
    required String deviceName,
    required String deviceId,
    required String category,
    required LogSeverity severity,
    required String location,
    required String notes,
    String? seat,
    List<String> photoPaths = const [],
  }) {
    final seatId = seat?.trim().toUpperCase() ?? '';
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
      seat: seatId.isEmpty ? null : seatId,
      photoPaths: List.unmodifiable(photoPaths),
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
    String? seat,
  }) async {
    if (state.isSaving || state.isTakingPhoto) {
      return const ActionSaveResult._(ActionSaveStatus.busy);
    }
    final error = validate(
      deviceName: deviceName,
      location: location,
      seat: seat,
    );
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
      seat: seat,
      photoPaths: state.photoPaths,
    );
    state = state.copyWith(isSaving: true);
    try {
      await ref.read(sessionViewModelProvider.notifier).addLog(log);
      // The saved incident owns its photos now.
      _unsaved = const [];
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
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }
}

final actionEntryViewModelProvider =
    NotifierProvider.autoDispose<ActionEntryViewModel, ActionEntryState>(
      ActionEntryViewModel.new,
    );
