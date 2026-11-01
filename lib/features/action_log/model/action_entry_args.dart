import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// What the incident form is pre-filled with when opened from a scanner.
class ActionEntryArgs {
  const ActionEntryArgs({this.device, this.category, this.notes, this.seat});

  final ScannedDeviceModel? device;
  final String? category;
  final String? notes;

  /// Seat id to preselect, e.g. "C4" (from the hall map).
  final String? seat;
}
