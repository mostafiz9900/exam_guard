import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// What the incident form is pre-filled with when opened from a scanner.
class ActionEntryArgs {
  const ActionEntryArgs({this.device, this.category, this.notes});

  final ScannedDeviceModel? device;
  final String? category;
  final String? notes;
}
