import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/wifi/i_wifi_scan_service.dart';
import 'package:exam_guard/core/services/wifi/wifi_permission_gate.dart';

/// Wi-Fi access point scans through the native MethodChannel `exam_guard/wifi`
/// (see `WifiScanner.kt`).
///
/// While any owner is active, the state (permission, Location, Wi-Fi) is
/// polled every [_pollInterval] so problems clear quickly, and a scan is
/// requested at most every [_scanInterval] (Android allows a foreground app
/// 4 scans per 2 minutes; a throttled request just returns cached results).
///
/// On start the service asks for its own permission once (NEARBY_WIFI_DEVICES
/// on Android 13+, Location otherwise) and reports a denial via [problem].
/// When a problem appears an empty list is emitted on [results] so stale
/// access points don't linger.
class WifiScanServiceImpl implements IWifiScanService {
  WifiScanServiceImpl(
    this._logger, {
    bool? isAndroid,
    this._channel = const MethodChannel('exam_guard/wifi'),
    this._permissions = const WifiPermissionGate(),
    // 35 s keeps us under Android's 4-scans-per-2-minutes foreground limit
    // even after an app restart (the limit is counted per package).
    this._scanInterval = const Duration(seconds: 35),
    this._pollInterval = const Duration(seconds: 5),
    this._clock = DateTime.now,
  }) : _isAndroid = isAndroid ?? Platform.isAndroid {
    _problem = _isAndroid ? null : WifiScanProblem.unsupported;
  }

  final AppLogger _logger;
  final bool _isAndroid;
  final MethodChannel _channel;
  final WifiPermissionGate _permissions;
  final Duration _scanInterval;
  final Duration _pollInterval;
  final DateTime Function() _clock;

  final Set<String> _owners = {};
  final Set<String> _suspenders = {};
  final StreamController<List<WifiNetworkRecord>> _results =
      StreamController<List<WifiNetworkRecord>>.broadcast();
  final StreamController<WifiScanProblem?> _problems =
      StreamController<WifiScanProblem?>.broadcast();
  WifiScanProblem? _problem;

  Timer? _pollTimer;

  /// Last scan request; kept across owner sessions because Android's
  /// throttle counts per app, not per session.
  DateTime? _lastScan;
  bool _permissionRequested = false;
  bool _emittedThisRun = false;
  Future<void> _queue = Future.value();

  @override
  bool get isSupported => _isAndroid;

  @override
  Stream<List<WifiNetworkRecord>> get results => _results.stream;

  @override
  Stream<WifiScanProblem?> get problem async* {
    yield _problem;
    yield* _problems.stream;
  }

  void _setProblem(WifiScanProblem? problem) {
    if (problem == _problem) return;
    _problem = problem;
    if (!_problems.isClosed) _problems.add(problem);
    if (problem != null) _emit(const []);
  }

  void _emit(List<WifiNetworkRecord> list) {
    if (!_results.isClosed) _results.add(List.unmodifiable(list));
  }

  @override
  Future<void> start(String owner) {
    _owners.add(owner);
    return _serial(_sync);
  }

  @override
  Future<void> stop(String owner) {
    _owners.remove(owner);
    return _serial(_sync);
  }

  @override
  Future<void> suspend(String key) async => _suspenders.add(key);

  @override
  Future<void> resume(String key) async => _suspenders.remove(key);

  Future<void> _serial(Future<void> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.catchError((Object e, StackTrace st) {
      _logger.warning('Wi-Fi scan step failed', e, st);
    });
    return result;
  }

  Future<void> _sync() async {
    if (!isSupported) return;
    if (_owners.isEmpty) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _setProblem(null);
      return;
    }
    if (_pollTimer != null) return;
    _permissionRequested = false;
    _emittedThisRun = false;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _serial(_tick).ignore();
    });
    await _tick();
  }

  Future<void> _tick() async {
    if (_owners.isEmpty || _pollTimer == null) return;
    var status = await _status();
    if (status == null) return;

    if (!status.hasPermission && !_permissionRequested) {
      try {
        await _permissions.request(status.sdkInt);
        _permissionRequested = true;
      } catch (e, st) {
        // e.g. another permission dialog (BLE) is open — retry next tick.
        _logger.warning('Wi-Fi permission request failed', e, st);
      }
      if (_owners.isEmpty) return;
      status = await _status();
      if (status == null) return;
    }

    if (!status.hasPermission) {
      return _setProblem(WifiScanProblem.permissionDenied);
    }
    // Android 12 and lower only return results while Location is on.
    // (13+ uses NEARBY_WIFI_DEVICES with neverForLocation, see manifest.)
    if (status.sdkInt < 33 && !status.locationEnabled) {
      return _setProblem(WifiScanProblem.locationOff);
    }
    if (!status.wifiEnabled && !status.scanAlwaysAvailable) {
      return _setProblem(WifiScanProblem.wifiOff);
    }

    final now = _clock();
    final last = _lastScan;
    // While a finder screen holds a pause, keep the last results.
    final due =
        _suspenders.isEmpty &&
        (last == null || now.difference(last) >= _scanInterval);
    // A fresh owner (or a cleared problem) gets cached results right away
    // instead of waiting for the throttle window.
    if (!due && _emittedThisRun && _problem == null) return;

    final List<WifiNetworkRecord> list;
    try {
      if (due) {
        _lastScan = now;
        final reply = await _channel.invokeMapMethod<String, dynamic>('scan');
        if (reply?['started'] == false) {
          _logger.debug('Wi-Fi scan throttled; using cached results');
        }
        list = parseWifiResults(reply?['results']);
      } else {
        list = parseWifiResults(
          await _channel.invokeListMethod<dynamic>('getScanResults'),
        );
      }
    } on PlatformException catch (e, st) {
      if (e.code == 'permissionDenied') {
        return _setProblem(WifiScanProblem.permissionDenied);
      }
      _logger.warning('Wi-Fi scan failed', e, st);
      return;
    } on MissingPluginException catch (e, st) {
      _logger.warning('Wi-Fi channel missing', e, st);
      return;
    }
    if (_owners.isEmpty) return;

    // Some OEMs still gate results on Location even with neverForLocation.
    if (list.isEmpty && !status.locationEnabled) {
      return _setProblem(WifiScanProblem.locationOff);
    }
    _setProblem(null);
    _emittedThisRun = true;
    _emit(list);
  }

  Future<_WifiStatus?> _status() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('status');
      if (map == null) return null;
      return _WifiStatus(
        sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
        wifiEnabled: map['wifiEnabled'] == true,
        scanAlwaysAvailable: map['scanAlwaysAvailable'] == true,
        locationEnabled: map['locationEnabled'] == true,
        hasPermission: map['hasPermission'] == true,
      );
    } on PlatformException catch (e, st) {
      _logger.warning('Wi-Fi status failed', e, st);
    } on MissingPluginException catch (e, st) {
      _logger.warning('Wi-Fi channel missing', e, st);
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    _owners.clear();
    await _serial(_sync);
    await _problems.close();
    await _results.close();
  }
}

class _WifiStatus {
  const _WifiStatus({
    required this.sdkInt,
    required this.wifiEnabled,
    required this.scanAlwaysAvailable,
    required this.locationEnabled,
    required this.hasPermission,
  });

  final int sdkInt;
  final bool wifiEnabled;
  final bool scanAlwaysAvailable;
  final bool locationEnabled;
  final bool hasPermission;
}

/// Parses the native result list; skips entries without a BSSID.
List<WifiNetworkRecord> parseWifiResults(Object? raw, {DateTime? timestamp}) {
  if (raw is! List) return const [];
  final at = timestamp ?? DateTime.now();
  final out = <WifiNetworkRecord>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final bssid = item['bssid']?.toString().trim().toUpperCase() ?? '';
    if (bssid.isEmpty) continue;
    out.add(
      WifiNetworkRecord(
        ssid: normalizeSsid(item['ssid']?.toString()),
        bssid: bssid,
        rssi: (item['level'] as num?)?.toInt() ?? -127,
        frequencyMhz: (item['frequency'] as num?)?.toInt() ?? 0,
        capabilities: item['capabilities']?.toString() ?? '',
        timestamp: at,
      ),
    );
  }
  return out;
}

/// Android may report SSIDs quoted, as `<unknown ssid>`, or padded with NULs
/// for hidden networks; all of those become a plain name or empty.
String normalizeSsid(String? raw) {
  var s = (raw ?? '').replaceAll('\u0000', '').trim();
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    s = s.substring(1, s.length - 1);
  }
  if (s == '<unknown ssid>') return '';
  return s;
}
