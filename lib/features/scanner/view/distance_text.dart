import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/features/scanner/model/distance_estimate.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// Teacher-friendly approximate distance for a BLE signal, e.g. "≈3 m",
/// "<1 m" or ">10 m". Whole metres only: the estimate is rough.
String approxDistanceText(num rssi, {int? txPower}) {
  final m = DistanceEstimate.forDevice(rssi, txPower);
  if (m < 1) return 'dist_under_one'.tr();
  if (m >= 10) return 'radar_distance_far'.tr(args: {'meters': '10'});
  return 'radar_distance_approx'.tr(args: {'meters': '${m.round()}'});
}

/// "≈3 m away" for BLE. Wi-Fi access points transmit far stronger and
/// classic inquiry often has no real level, so those keep their dBm.
String signalSummaryText(num rssi, DeviceTransport transport, {int? txPower}) =>
    transport == DeviceTransport.ble
    ? 'dist_away'.tr(
        args: {'distance': approxDistanceText(rssi, txPower: txPower)},
      )
    : '$rssi dBm';
