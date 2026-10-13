import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/core/utils/app_date_format.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/session/model/action_log_model.dart';
import 'package:exam_guard/features/session/model/session_model.dart';

/// Formats a single incident as an official text report and shares it.
class ActionLogRepository {
  ActionLogRepository(this._share);

  final IShareService _share;

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
Report Generated At: $timestamp
Institute / Center : ${orDash(session?.instituteName)}
Exam Room / Hall   : ${orDash(session?.roomNumber)}
Inspector In-Charge: ${orDash(session?.teacherName)}
Candidate Seat No. : ${orDash(log.location)}

-----------------------------------------------------------------
[INCIDENT]
-----------------------------------------------------------------
Category           : ${orDash(log.category)}
Severity           : ${log.severity.code}
Device Name        : ${orDash(log.deviceName)}
MAC Address / ID   : ${orDash(log.deviceId)}
Hardware Vendor    : ${orDash(scannedDevice?.manufacturer)}
Last RSSI          : ${scannedDevice == null ? '-' : '${scannedDevice.rssi} dBm'}

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

  Future<ShareOutcome> shareReport(String text, {required String subject}) =>
      _share.shareText(text, subject: subject);
}

final actionLogRepositoryProvider = Provider<ActionLogRepository>(
  (ref) => ActionLogRepository(ref.watch(shareServiceProvider)),
);
