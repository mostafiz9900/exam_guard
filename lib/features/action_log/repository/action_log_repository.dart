import 'dart:ui' show Rect;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/camera/i_photo_service.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';

/// Evidence photos of an incident, its text report and sharing.
class ActionLogRepository {
  ActionLogRepository(this._share, this._photos);

  final IShareService _share;
  final IPhotoService _photos;

  /// Opens the camera. Returns the saved file path, or null if cancelled.
  /// Throws [PhotoException] when the photo could not be taken.
  Future<String?> takePhoto() => _photos.takePhoto();

  Future<void> deletePhoto(String path) => _photos.delete(path);

  String buildTextReport({
    required ActionLogModel log,
    required SessionModel? session,
    ScannedDeviceModel? scannedDevice,
  }) {
    final timestamp = AppDateFormat.fullDateTime(log.createdAt);
    String orDash(String? v) => v == null || v.isEmpty ? '-' : v;

    return '''
=================================================================
             OFFICIAL EXAM SECURITY VIOLATION REPORT
=================================================================
Incident Logged At : $timestamp
Institute / Center : ${orDash(session?.instituteName)}
Exam Room / Hall   : ${orDash(session?.roomNumber)}
Inspector In-Charge: ${orDash(session?.teacherName)}
Candidate Seat No. : ${orDash(log.seat)}
Location Note      : ${orDash(log.location)}

-----------------------------------------------------------------
[INCIDENT]
-----------------------------------------------------------------
Category           : ${orDash(log.category)}
Severity           : ${log.severity.code}
Device Name        : ${orDash(log.deviceName)}
Device ID          : ${orDash(log.deviceId)}
Hardware Vendor    : ${orDash(scannedDevice?.manufacturer)}
Last RSSI          : ${scannedDevice == null ? '-' : '${scannedDevice.rssi} dBm'}
Evidence Photos    : ${log.photoPaths.isEmpty ? 'None' : '${log.photoPaths.length} attached'}

-----------------------------------------------------------------
[INSPECTOR NOTES]
-----------------------------------------------------------------
${orDash(log.notes)}

-----------------------------------------------------------------
Inspector Signature: _______________________
Date: $timestamp
=================================================================
''';
  }

  Future<ShareOutcome> shareReport(
    String text, {
    required String subject,
    Rect? origin,
  }) => _share.shareText(text, subject: subject, origin: origin);
}

final actionLogRepositoryProvider = Provider<ActionLogRepository>(
  (ref) => ActionLogRepository(
    ref.watch(shareServiceProvider),
    ref.watch(photoServiceProvider),
  ),
);
