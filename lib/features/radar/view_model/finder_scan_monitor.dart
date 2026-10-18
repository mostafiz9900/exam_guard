import 'dart:async';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/features/radar/model/finder_scan_issue.dart';
import 'package:exam_guard/features/radar/repository/radar_repository.dart';

/// Follows what blocks the shared BLE scan (Location off, Bluetooth off)
/// for the finder screens and reports the current blocking issue.
///
/// Scan start / stream failures are reported separately with [setError];
/// they clear once a packet arrives again ([clearError]).
class FinderScanMonitor {
  FinderScanMonitor(this._repository, this._logger, this._onChange);

  final RadarRepository _repository;
  final AppLogger _logger;
  final void Function(FinderScanIssue? issue) _onChange;

  StreamSubscription<BleScanError?>? _problemSub;
  StreamSubscription<BleAdapterStatus>? _adapterSub;
  bool _locationOff = false;
  bool _bluetoothOff = false;
  FinderScanIssue? _error;
  FinderScanIssue? _reported;

  FinderScanIssue? get issue {
    if (_bluetoothOff) return FinderScanIssue.bluetoothOff;
    if (_locationOff) return FinderScanIssue.locationOff;
    return _error;
  }

  void start() {
    stop();
    _problemSub = _repository.scanProblem().listen(
      (problem) {
        _locationOff = problem == BleScanError.locationOff;
        _emit();
      },
      onError: (Object e, StackTrace st) =>
          _logger.warning('Finder scan problem stream error', e, st),
    );
    _adapterSub = _repository.adapterStatus().listen(
      (status) {
        _bluetoothOff = switch (status) {
          BleAdapterStatus.off ||
          BleAdapterStatus.unauthorized ||
          BleAdapterStatus.unavailable => true,
          BleAdapterStatus.on || BleAdapterStatus.unknown => false,
        };
        _emit();
      },
      onError: (Object e, StackTrace st) =>
          _logger.warning('Finder adapter stream error', e, st),
    );
  }

  /// Maps a scan failure to an issue and reports it.
  void setError(Object error) {
    _error = switch (error) {
      BleScanException(code: BleScanError.locationOff) =>
        FinderScanIssue.locationOff,
      BleScanException(code: BleScanError.throttled) =>
        FinderScanIssue.throttled,
      _ => FinderScanIssue.failed,
    };
    _emit();
  }

  /// A packet arrived: earlier scan failures are over.
  void clearError() {
    if (_error == null) return;
    _error = null;
    _emit();
  }

  void stop() {
    _problemSub?.cancel();
    _adapterSub?.cancel();
    _problemSub = null;
    _adapterSub = null;
    _locationOff = false;
    _bluetoothOff = false;
    _error = null;
    _reported = null;
  }

  void _emit() {
    final current = issue;
    if (current == _reported) return;
    _reported = current;
    _onChange(current);
  }
}
