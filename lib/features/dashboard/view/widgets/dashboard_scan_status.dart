import 'package:flutter/material.dart';

import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';

/// Scanner status as the dashboard shows it.
enum DashboardScanStatus { live, bluetoothOff, locationOff, failed, stopped }

/// Only blocking problems count: [ScannerState.errorMessage] is a blocking
/// scan problem, while transient notices ([ScannerState.noticeKey]) are not
/// failures and never turn the chip into "SCAN FAILED".
DashboardScanStatus dashboardScanStatusOf(ScannerState s) {
  if (s.isBluetoothOff) return DashboardScanStatus.bluetoothOff;
  if (s.isLocationOff) return DashboardScanStatus.locationOff;
  if (s.errorMessage != null) return DashboardScanStatus.failed;
  if (s.isScanning) return DashboardScanStatus.live;
  return DashboardScanStatus.stopped;
}

/// Amber warning that stays readable on light and dark surfaces.
Color dashboardWarningColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Colors.amber.shade300
    : Colors.orange.shade800;
