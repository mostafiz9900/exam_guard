import 'package:easy_localization/easy_localization.dart';

import '../../../features/scanner/domain/scanned_device_model.dart';
import '../../../features/session/domain/session_model.dart';

/// Service to generate & export official Exam Violation Incident Reports
class ViolationReportService {
  ViolationReportService._();
  static final ViolationReportService instance = ViolationReportService._();

  /// Generates a clean text/markdown official report document
  String generateTextReport({
    required ScannedDeviceModel? device,
    required SessionModel? session,
    required String candidateSeat,
    required String inspectorNotes,
  }) {
    final now = DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd hh:mm:ss a').format(now);
    final room = session?.roomNumber ?? 'Unspecified Room';
    final institute = session?.instituteName ?? 'Exam Center';
    final teacher = session?.teacherName ?? 'Exam Inspector';

    final deviceName = device?.displayName ?? 'Unauthorized Electronic Device';
    final macAddress = device?.id ?? 'N/A';
    final manufacturer = device?.manufacturer ?? 'Generic RF Hardware';
    final rssi = device != null ? '${device.rssi} dBm' : 'N/A';

    return '''
=================================================================
             OFFICIAL EXAM SECURITY VIOLATION REPORT             
=================================================================
Report Generated At: $timestamp
Institute / Center : $institute
Exam Room / Hall   : $room
Inspector In-Charge: $teacher
Candidate Seat No. : ${candidateSeat.isNotEmpty ? candidateSeat : 'Under Investigation'}

-----------------------------------------------------------------
[EVIDENCE & DEVICE TECHNICAL DETAILS]
-----------------------------------------------------------------
Device Name        : $deviceName
Hardware Vendor    : $manufacturer
MAC Address / ID   : $macAddress
RSSI Signal Power  : $rssi
Security Threat    : HIGH RISK / UNAUTHORIZED RF TRANSMITTER

-----------------------------------------------------------------
[INSPECTOR INCIDENT NOTES]
-----------------------------------------------------------------
${inspectorNotes.isNotEmpty ? inspectorNotes : 'Unauthorized wireless transmission detected during active exam session.'}

-----------------------------------------------------------------
[OFFICIAL CERTIFICATION & VERIFICATION]
-----------------------------------------------------------------
I hereby certify that the digital evidence detailed above was 
detected live using ExamGuard RF Spectrum Inspection Tool.

Inspector Signature: _______________________
Date: $timestamp
=================================================================
''';
  }

  /// Formats report as CSV for data export
  String generateCsvReport({
    required ScannedDeviceModel? device,
    required SessionModel? session,
    required String candidateSeat,
    required String inspectorNotes,
  }) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final room = session?.roomNumber ?? '';
    final institute = session?.instituteName ?? '';
    final teacher = session?.teacherName ?? '';

    final deviceName = device?.displayName ?? 'Unknown';
    final macAddress = device?.id ?? '';
    final rssi = device?.rssi.toString() ?? '';

    final header = 'Timestamp,Institute,Room,Inspector,CandidateSeat,DeviceName,MAC,RSSI,Notes\n';
    final row = '"$timestamp","$institute","$room","$teacher","$candidateSeat","$deviceName","$macAddress","$rssi","$inspectorNotes"\n';

    return header + row;
  }
}
