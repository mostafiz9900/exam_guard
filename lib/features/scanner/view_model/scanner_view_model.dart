import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/services/wifi/i_wifi_scan_service.dart';
import 'package:exam_guard/features/scanner/model/new_device_alert.dart';
import 'package:exam_guard/features/scanner/model/presence_tracker.dart';
import 'package:exam_guard/features/scanner/model/room_equipment.dart';
import 'package:exam_guard/features/session/model/activity_sample.dart';
import 'package:exam_guard/features/session/model/room_profile.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_group.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/repository/scanner_repository.dart';
import 'package:exam_guard/features/scanner/repository/wireless_classifier.dart';
import 'package:exam_guard/features/scanner/view_model/device_filter.dart';
import 'package:exam_guard/features/scanner/view_model/device_grouping.dart';
import 'package:exam_guard/features/scanner/view_model/list_order.dart';
import 'package:exam_guard/features/scanner/view_model/signal_smoothing.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

export 'package:exam_guard/core/services/wifi/i_wifi_scan_service.dart'
    show WifiScanProblem;
export 'package:exam_guard/features/scanner/model/new_device_alert.dart';
export 'package:exam_guard/features/scanner/model/scanned_device_group.dart';
export 'package:exam_guard/features/scanner/model/scanned_device_model.dart'
    show DeviceTransport;
export 'package:exam_guard/features/scanner/view_model/device_filter.dart';
export 'package:exam_guard/features/scanner/view_model/list_order.dart'
    show ScanSortMode;
export 'package:exam_guard/features/scanner/view_model/signal_smoothing.dart'
    show ProximityBand;

enum RoomSizePreset {
  small('scan_room_small', -75),
  medium('scan_room_medium', -85),
  large('scan_room_large', -95);

  const RoomSizePreset(this.labelKey, this.rssiThreshold);

  /// Translation key of the preset's display name.
  final String labelKey;
  final int rssiThreshold;
}

/// Why the scanner list is empty, so the screen can say what to do.
enum ScannerEmptyReason {
  /// Android needs Location on to return BLE results.
  locationOff,
  bluetoothOff,

  /// A blocking problem in [ScannerState.errorMessage].
  error,

  /// Scanning, nothing has advertised yet.
  waiting,

  /// Scanning is stopped and nothing was found.
  paused,

  /// Devices were found but the room boundary hides all of them.
  outsideBoundary,

  /// Devices are in range but the selected filter matches none.
  filteredOut,
}

class ScannerState {
  ScannerState({
    this.isScanning = false,
    this.devices = const [],
    List<ScannedDeviceGroup>? groups,
    this.isRoomBoundaryMode = false,
    this.roomSizePreset = RoomSizePreset.medium,
    this.isBluetoothOff = false,
    this.isLocationOff = false,
    this.errorMessage,
    this.errorArgs = const {},
    this.noticeKey,
    this.noticeArgs = const {},
    this.noticeId = 0,
    this.alerts = const [],
    this.alertSeq = 0,
    this.trustedIds = const {},
    this.baselineAt,
    this.wifiProblem,
    this.sortMode = ScanSortMode.stable,
    this.staleIds = const {},
    this.bands = const {},
    this.asOf,
    this.isSelecting = false,
    this.selectedIds = const {},
    this.hasSeatLayout = false,
    this.identityVersion = 0,
    this.togglingIds = const {},
  }) : _groups = groups;

  /// Most devices the walk finder follows at once.
  static const int maxWalkTargets = 5;

  /// Devices picked by "Walk & find strongest untrusted".
  static const int strongestPickCount = 3;

  /// True while the scan owner is registered. It stays true while
  /// [isLocationOff]; the scan then resumes by itself.
  final bool isScanning;

  /// Every address heard recently (one entry per address), newest first.
  /// BLE [ScannedDeviceModel.rssi] is smoothed (see `RssiSmoother`).
  final List<ScannedDeviceModel> devices;

  /// Groups in display order, as published by the view model (sticky
  /// grouping, stable or nearest order). Null: grouped from [devices].
  final List<ScannedDeviceGroup>? _groups;

  final bool isRoomBoundaryMode;
  final RoomSizePreset roomSizePreset;
  final bool isBluetoothOff;

  /// Location (GPS) is off, so Android returns no BLE results. The scan
  /// keeps its place and resumes once Location is turned on.
  final bool isLocationOff;

  /// Translation key of a blocking scan problem (permission, Bluetooth
  /// off/unsupported, scan failed), or null when scanning can work.
  final String? errorMessage;

  /// Placeholder values for [errorMessage].
  final Map<String, String> errorArgs;

  /// Translation key of the latest one-off message (e.g. a failed
  /// connection) to show once, e.g. in a snackbar. Never blocks scanning.
  final String? noticeKey;

  /// Placeholder values for [noticeKey].
  final Map<String, String> noticeArgs;

  /// Increases with every new notice, so a repeated identical notice can
  /// still be told apart from the previous one.
  final int noticeId;

  /// New-device alerts raised since the baseline, newest first. Removed when
  /// the device is trusted.
  final List<NewDeviceAlert> alerts;

  /// Increases with every new alert (e.g. to vibrate once per alert).
  final int alertSeq;

  /// Device ids marked as belonging to the room or the invigilator (from
  /// the running exam session).
  final Set<String> trustedIds;

  /// When the empty-room baseline was taken, or null.
  final DateTime? baselineAt;

  /// Why Wi-Fi hotspot detection isn't working, or null when it is.
  /// [WifiScanProblem.unsupported] (iOS) is expected and not worth showing.
  final WifiScanProblem? wifiProblem;

  /// List order chosen for this session.
  final ScanSortMode sortMode;

  /// Devices silent for a while: still listed (muted, "last seen Xs ago")
  /// until they are removed.
  final Set<String> staleIds;

  /// Proximity band per device id, with hysteresis.
  final Map<String, ProximityBand> bands;

  /// When this state was published (for "last seen Xs ago").
  final DateTime? asOf;

  /// Multi-select mode for "Walk & find".
  final bool isSelecting;

  /// Device ids picked for "Walk & find" (at most [maxWalkTargets]).
  final Set<String> selectedIds;

  /// The running exam has a seat layout, so "Seat sweep" is possible.
  final bool hasSeatLayout;

  /// Increases whenever the scanner's idea of which addresses belong to one
  /// physical device changes (an address rotated, or the members of a
  /// group changed). Finders re-read [ScannerViewModel.aliasesOf] then.
  final int identityVersion;

  /// BLE devices that keep disappearing and coming back (switched on and
  /// off to dodge the scan). See [PresenceTracker].
  final Set<String> togglingIds;

  bool get hasBaseline => baselineAt != null;

  int get unacknowledgedAlertCount =>
      alerts.where((a) => !a.acknowledged).length;

  bool isTrusted(String deviceId) => trustedIds.contains(deviceId);

  /// A group is trusted when any of its addresses is.
  bool isGroupTrusted(ScannedDeviceGroup group) =>
      group.members.any((m) => trustedIds.contains(m.id));

  /// True when [group] has an alert the invigilator hasn't seen yet.
  bool hasUnacknowledgedAlert(ScannedDeviceGroup group) => alerts.any(
    (a) => !a.acknowledged && group.members.any((m) => m.id == a.deviceId),
  );

  bool isStale(String deviceId) => staleIds.contains(deviceId);

  /// Every address of [group] has gone quiet.
  bool isGroupStale(ScannedDeviceGroup group) =>
      group.members.every((m) => staleIds.contains(m.id));

  /// Whole seconds since [device] was last heard.
  int secondsSinceSeen(ScannedDeviceModel device) {
    final s = (asOf ?? DateTime.now()).difference(device.lastSeen).inSeconds;
    return s < 0 ? 0 : s;
  }

  /// Proximity of [device] (from its smoothed signal, with hysteresis).
  ProximityBand bandOf(ScannedDeviceModel device) =>
      bands[device.id] ?? ProximityBand.fromRssi(device.rssi);

  bool isGroupSelected(ScannedDeviceGroup group) =>
      group.members.any((m) => selectedIds.contains(m.id));

  /// Selected devices in list order.
  List<ScannedDeviceModel> get selectedDevices => [
    for (final g in groups)
      for (final m in g.members)
        if (selectedIds.contains(m.id)) m,
  ];

  /// "Seat sweep" needs a live BLE signal. Without a seat map the sweep
  /// screen lets the inspector set one, so the option is always offered.
  bool canSeatSweep(ScannedDeviceModel device) => device.isBle;

  /// The [count] strongest untrusted BLE devices still being heard (the
  /// strongest address of each group).
  List<ScannedDeviceModel> strongestUntrusted([
    int count = strongestPickCount,
  ]) {
    final candidates = [
      for (final g in activeGroups)
        if (g.primary.isBle && !isGroupTrusted(g) && !isGroupStale(g))
          g.members
              .where((m) => !staleIds.contains(m.id))
              .reduce((a, b) => b.rssi > a.rssi ? b : a),
    ]..sort((a, b) => b.rssi.compareTo(a.rssi));
    return candidates.take(count).toList();
  }

  /// Number of [groups] per transport (of each group's primary).
  static Map<DeviceTransport, int> countByTransport(
    Iterable<ScannedDeviceGroup> groups,
  ) {
    final counts = {for (final t in DeviceTransport.values) t: 0};
    for (final g in groups) {
      counts[g.primary.transport] = counts[g.primary.transport]! + 1;
    }
    return counts;
  }

  /// Devices left after the room boundary filter (one per address).
  late final List<ScannedDeviceModel> activeDevices = isRoomBoundaryMode
      ? devices.where((d) => d.rssi >= roomSizePreset.rssiThreshold).toList()
      : devices;

  /// [devices] with addresses that likely belong to one device grouped, in
  /// display order.
  late final List<ScannedDeviceGroup> groups =
      _groups ?? groupLikelySameDevices(devices);

  /// [groups] after the room boundary filter; members outside the
  /// boundary are left out of each group.
  late final List<ScannedDeviceGroup> activeGroups = isRoomBoundaryMode
      ? [
          for (final g in groups)
            if (g.members.any(_insideBoundary))
              ScannedDeviceGroup(g.members.where(_insideBoundary).toList()),
        ]
      : groups;

  bool _insideBoundary(ScannedDeviceModel d) =>
      d.rssi >= roomSizePreset.rssiThreshold;

  /// Returns list of successfully connected target devices
  List<ScannedDeviceModel> get connectedDevices {
    return devices.where((d) => d.isConnected).toList();
  }

  /// Groups shown for [filter], in display order; a group is matched on
  /// its primary. "Near me" leaves out devices that went quiet.
  List<ScannedDeviceGroup> visibleGroups(DeviceFilter filter) => [
    for (final g in activeGroups)
      if (filter.matches(g.primary) &&
          !(filter == DeviceFilter.nearMe && isGroupStale(g)))
        g,
  ];

  /// Why nothing is shown for [filter], or null when something is.
  ScannerEmptyReason? emptyReason(DeviceFilter filter) {
    if (visibleGroups(filter).isNotEmpty) return null;
    if (isLocationOff) return ScannerEmptyReason.locationOff;
    if (isBluetoothOff) return ScannerEmptyReason.bluetoothOff;
    if (errorMessage != null) return ScannerEmptyReason.error;
    if (devices.isEmpty) {
      return isScanning
          ? ScannerEmptyReason.waiting
          : ScannerEmptyReason.paused;
    }
    if (activeDevices.isEmpty) return ScannerEmptyReason.outsideBoundary;
    return ScannerEmptyReason.filteredOut;
  }

  /// Passing [devices] without [groups] regroups from scratch.
  ScannerState copyWith({
    bool? isScanning,
    List<ScannedDeviceModel>? devices,
    List<ScannedDeviceGroup>? groups,
    bool? isRoomBoundaryMode,
    RoomSizePreset? roomSizePreset,
    bool? isBluetoothOff,
    bool? isLocationOff,
    String? errorMessage,
    Map<String, String>? errorArgs,
    bool clearError = false,
    String? noticeKey,
    Map<String, String>? noticeArgs,
    int? noticeId,
    List<NewDeviceAlert>? alerts,
    int? alertSeq,
    Set<String>? trustedIds,
    DateTime? baselineAt,
    bool clearBaseline = false,
    WifiScanProblem? wifiProblem,
    bool clearWifiProblem = false,
    ScanSortMode? sortMode,
    Set<String>? staleIds,
    Map<String, ProximityBand>? bands,
    DateTime? asOf,
    bool? isSelecting,
    Set<String>? selectedIds,
    bool? hasSeatLayout,
    int? identityVersion,
    Set<String>? togglingIds,
  }) {
    return ScannerState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      groups: groups ?? (devices != null ? null : _groups),
      isRoomBoundaryMode: isRoomBoundaryMode ?? this.isRoomBoundaryMode,
      roomSizePreset: roomSizePreset ?? this.roomSizePreset,
      isBluetoothOff: isBluetoothOff ?? this.isBluetoothOff,
      isLocationOff: isLocationOff ?? this.isLocationOff,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorArgs: clearError
          ? const {}
          : (errorArgs ?? (errorMessage != null ? const {} : this.errorArgs)),
      noticeKey: noticeKey ?? this.noticeKey,
      noticeArgs:
          noticeArgs ?? (noticeKey != null ? const {} : this.noticeArgs),
      noticeId: noticeId ?? this.noticeId,
      alerts: alerts ?? this.alerts,
      alertSeq: alertSeq ?? this.alertSeq,
      trustedIds: trustedIds ?? this.trustedIds,
      baselineAt: clearBaseline ? null : (baselineAt ?? this.baselineAt),
      wifiProblem: clearWifiProblem ? null : (wifiProblem ?? this.wifiProblem),
      sortMode: sortMode ?? this.sortMode,
      staleIds: staleIds ?? this.staleIds,
      bands: bands ?? this.bands,
      asOf: asOf ?? this.asOf,
      isSelecting: isSelecting ?? this.isSelecting,
      selectedIds: selectedIds ?? this.selectedIds,
      hasSeatLayout: hasSeatLayout ?? this.hasSeatLayout,
      identityVersion: identityVersion ?? this.identityVersion,
      togglingIds: togglingIds ?? this.togglingIds,
    );
  }
}

/// Current time for the scanner (overridden in tests).
final scannerClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Live device discovery: BLE advertisements (continuous), classic
/// Bluetooth inquiry and Wi-Fi scans (every ~30 s), merged into one list.
/// Also keeps the trusted-device list in sync with the exam session and
/// raises [NewDeviceAlert]s for devices that appear after the baseline.
///
/// Sightings go into a private live store; the list is published at most
/// every [_publishEvery] (immediately when a device appears or leaves, or
/// for classic / Wi-Fi results), so the screen isn't rebuilt per packet.
class ScannerViewModel extends Notifier<ScannerState> {
  /// A BLE device that has not advertised for this long is removed.
  static const Duration _goneAfter = Duration(seconds: 30);

  /// Classic Bluetooth and Wi-Fi results refresh only every ~35 s, and a
  /// throttled Wi-Fi scan (Android: 4 per 2 min) doubles that gap.
  static const Duration _slowGoneAfter = Duration(seconds: 150);

  /// A BLE device silent this long is shown muted ("last seen Xs ago").
  static const Duration _staleAfter = Duration(seconds: 15);
  static const Duration _slowStaleAfter = Duration(seconds: 75);

  /// Live values are coalesced and published at most this often.
  static const Duration _publishEvery = Duration(milliseconds: 250);

  /// Phones, watches and earbuds change their random BLE address every few
  /// minutes. An entry silent for this long that looks exactly like a newly
  /// appeared address is treated as the same device.
  static const Duration _rotationGap = Duration(seconds: 5);

  /// A new BLE device must be heard over at least this long before it
  /// raises an alert (one stray packet is not enough).
  static const Duration _bleConfirmSpan = Duration(seconds: 3);

  /// Nameless nearby devices are briefly connected to, one at a time, to
  /// read the name stored inside them. A new candidate at most this often.
  static const Duration _nameLookupEvery = Duration(seconds: 4);
  static const Duration _nameLookupTimeout = Duration(seconds: 10);

  /// Only devices about inside the room are worth a connection.
  static const int _nameLookupMinRssi = -80;

  /// Lookups per scan, so rotating addresses can't keep the radio busy.
  static const int _maxNameLookups = 40;

  /// Minimum signal for an alert: about inside the room.
  static const int _alertRssi = -75;
  static const int _hotspotAlertRssi = -80;

  late ScannerRepository _repository;
  late AppLogger _logger;
  late DateTime Function() _now;

  StreamSubscription<ScannedDeviceModel>? _sightingsSub;
  StreamSubscription<ScannedDeviceModel>? _classicSub;
  StreamSubscription<List<ScannedDeviceModel>>? _wifiSub;
  StreamSubscription<bool>? _adapterSub;
  StreamSubscription<BleScanError?>? _problemSub;
  StreamSubscription<WifiScanProblem?>? _wifiProblemSub;
  Timer? _evictTimer;
  Timer? _activityTimer;
  static const Duration _activityEvery = Duration(minutes: 1);
  Timer? _nameLookupTimer;
  final Set<String> _nameLookupTried = {};
  String? _nameLookupId;
  int _nameLookupsLeft = _maxNameLookups;

  /// Names the OS knows (paired / connected devices), by id.
  Map<String, String> _knownNames = const {};
  Timer? _publishTimer;
  Future<void>? _starting;

  /// Latest known model per address (BLE rssi = last raw sample).
  final Map<String, ScannedDeviceModel> _live = {};

  /// Order of first appearance per address (stable list order).
  final Map<String, int> _appearance = {};
  int _nextAppearance = 0;

  final RssiSmoother _smoother = RssiSmoother();
  final PresenceTracker _presence = PresenceTracker();
  final Map<String, ProximityBand> _bands = {};
  final StickyDeviceGrouper _grouper = StickyDeviceGrouper();
  final NearestOrder _nearest = NearestOrder();

  /// The running exam (trusted ids and baseline live there), or null.
  SessionModel? _session;

  /// Trust and baseline kept in memory when no exam session can store them.
  final Set<String> _localTrusted = {};
  DateTime? _localBaselineAt;

  /// Every device that has raised an alert (or belongs to one that has).
  final Set<String> _alertedIds = {};

  /// Rotated address → the first address of that device (its identity
  /// root). Kept after the old address is forgotten, so a finder that
  /// started on the old address still follows the device.
  final Map<String, String> _identityRoot = {};

  /// Oldest rotation records are dropped beyond this many.
  static const int _maxIdentityRecords = 2000;

  int _identityVersion = 0;

  /// Member ids of every multi-address group at the last publish.
  String _groupSignature = '';

  @override
  ScannerState build() {
    _repository = ref.watch(scannerRepositoryProvider);
    _logger = ref.watch(appLoggerProvider);
    _now = ref.watch(scannerClockProvider);
    _forgetAll();

    ref.onDispose(() {
      _publishTimer?.cancel();
      _publishTimer = null;
      _stop();
    });

    _adapterSub = _repository.bluetoothOn().listen(_onBluetoothOn);
    _problemSub = _repository.scanProblem().listen(
      _onScanProblem,
      onError: (Object e, StackTrace st) =>
          _logger.warning('BLE scan problem stream failed', e, st),
    );
    _wifiProblemSub = _repository.wifiProblem().listen(
      _onWifiProblem,
      onError: (Object e, StackTrace st) =>
          _logger.warning('Wi-Fi problem stream failed', e, st),
    );

    _session = _readSession();
    Future.microtask(() => toggleScanning(true));
    return ScannerState(
      trustedIds: _trustedIds(),
      baselineAt: _baselineAt(),
      hasSeatLayout: _session?.hasSeatLayout ?? false,
      identityVersion: _identityVersion,
    );
  }

  // ── Identity: addresses of one physical device ───────────────────────

  String _rootOf(String id) => _identityRoot[id] ?? id;

  /// Every address currently believed to be the same physical device as
  /// [deviceId]: the addresses it rotated to (or from), every member of a
  /// live group containing one of them, and [deviceId] itself. Never empty.
  /// Re-read when [ScannerState.identityVersion] changes.
  Set<String> aliasesOf(String deviceId) {
    final ids = <String>{deviceId};
    final groups = state.groups;
    var grew = true;
    while (grew) {
      grew = false;
      final roots = {for (final id in ids) _rootOf(id)};
      for (final r in roots) {
        if (ids.add(r)) grew = true;
      }
      for (final e in _identityRoot.entries) {
        if (roots.contains(e.value) && ids.add(e.key)) grew = true;
      }
      for (final g in groups) {
        if (!g.isGrouped || !g.members.any((m) => ids.contains(m.id))) {
          continue;
        }
        for (final m in g.members) {
          if (ids.add(m.id)) grew = true;
        }
      }
    }
    return ids;
  }

  /// [newId] is [oldId]'s device under a new random address.
  void _recordRotation(String oldId, String newId) {
    _identityRoot.remove(newId);
    _identityRoot[newId] = _rootOf(oldId);
    if (_identityRoot.length > _maxIdentityRecords) {
      _identityRoot.remove(_identityRoot.keys.first);
    }
    _identityVersion++;
  }

  /// Cheap fingerprint of which addresses are grouped together.
  static String _signatureOf(List<ScannedDeviceGroup> groups) {
    final parts = [
      for (final g in groups)
        if (g.isGrouped) ([for (final m in g.members) m.id]..sort()).join(','),
    ]..sort();
    return parts.join('|');
  }

  // ── Session: trusted devices and baseline ────────────────────────────

  SessionModel? _readSession() {
    try {
      ref.listen<SessionModel?>(
        sessionViewModelProvider,
        (_, next) => _onSession(next),
        onError: (Object e, StackTrace st) =>
            _logger.warning('Session unavailable to the scanner', e, st),
      );
      return _activeOnly(ref.read(sessionViewModelProvider));
    } catch (e, st) {
      _logger.warning('Session unavailable to the scanner', e, st);
      return null;
    }
  }

  static SessionModel? _activeOnly(SessionModel? s) =>
      s != null && s.isActive ? s : null;

  void _onSession(SessionModel? next) {
    if (!ref.mounted) return;
    final active = _activeOnly(next);
    if (active?.id != _session?.id) {
      // Another exam: its own trust list, baseline and alerts.
      _localTrusted.clear();
      _localBaselineAt = null;
      _alertedIds.clear();
      state = state.copyWith(alerts: const []);
    }
    _session = active;
    _applyTrust();
  }

  Set<String> _trustedIds() => {
    ...?_session?.trustedDeviceIds,
    ..._localTrusted,
  };

  DateTime? _baselineAt() => _session?.baselineAt ?? _localBaselineAt;

  /// Publishes trust/baseline; alerts of trusted devices are dropped.
  void _applyTrust() {
    final trusted = _trustedIds();
    final baseline = _baselineAt();
    state = state.copyWith(
      trustedIds: trusted,
      baselineAt: baseline,
      clearBaseline: baseline == null,
      hasSeatLayout: _session?.hasSeatLayout ?? false,
      alerts: [
        for (final a in state.alerts)
          if (!trusted.contains(a.deviceId)) a,
      ],
    );
    // "Nearest first" puts trusted devices last.
    if (state.sortMode == ScanSortMode.nearest) _publish();
  }

  /// Takes the empty-room baseline: every device known right now (all
  /// transports, every address of grouped devices) is trusted, and devices
  /// appearing later can raise alerts. Returns how many ids were trusted.
  Future<int> takeBaseline() async {
    final ids = {..._live.keys};
    try {
      await ref.read(sessionViewModelProvider.notifier).setBaseline(ids);
    } catch (e, st) {
      _logger.warning(
        'Baseline not saved to the session; kept in memory',
        e,
        st,
      );
      _localTrusted.addAll(ids);
      _localBaselineAt = _now();
    }
    if (ref.mounted) _applyTrust();
    await _rememberRoomEquipment();
    return ids.length;
  }

  /// Saves the fixed equipment seen now to this room's profile, so the
  /// next exam in the room starts with it trusted.
  Future<void> _rememberRoomEquipment() async {
    final items = [
      for (final d in _live.values)
        if (isRoomEquipment(d))
          RoomProfileItem(
            id: d.id,
            name: d.displayName,
            type: d.deviceType,
            transport: d.transport.name,
          ),
    ];
    try {
      await ref
          .read(sessionViewModelProvider.notifier)
          .rememberRoomEquipment(items);
    } catch (e, st) {
      _logger.warning('Room profile not saved', e, st);
    }
  }

  /// Records how busy the hall is now, for the report's activity chart.
  @visibleForTesting
  Future<void> recordActivityNow() async {
    if (!ref.mounted || !state.isScanning) return;
    final now = _now();
    final present = [
      for (final d in _live.values)
        if (!_isStaleAt(d, now)) d,
    ];
    try {
      await ref
          .read(sessionViewModelProvider.notifier)
          .addActivitySample(
            ActivitySample(
              at: now,
              devices: present.length,
              untrusted: present.where((d) => !state.isTrusted(d.id)).length,
              alerts: state.alerts.length,
            ),
          );
    } catch (e, st) {
      _logger.warning('Activity sample not saved', e, st);
    }
  }

  /// Trusts [deviceId] and every other address grouped with it. Its alert
  /// is removed.
  Future<void> trustDevice(String deviceId) async {
    final ids = _groupIdsOf(deviceId);
    try {
      final session = ref.read(sessionViewModelProvider.notifier);
      for (final id in ids) {
        await session.trustDevice(id);
      }
    } catch (e, st) {
      _logger.warning('Trust not saved to the session; kept in memory', e, st);
      _localTrusted.addAll(ids);
    }
    if (ref.mounted) _applyTrust();
  }

  /// Removes trust from [deviceId] and every address grouped with it.
  Future<void> untrustDevice(String deviceId) async {
    final ids = _groupIdsOf(deviceId);
    _localTrusted.removeAll(ids);
    try {
      final session = ref.read(sessionViewModelProvider.notifier);
      for (final id in ids) {
        if (_session?.trustedDeviceIds.contains(id) ?? false) {
          await session.untrustDevice(id);
        }
      }
    } catch (e, st) {
      _logger.warning('Untrust not saved to the session', e, st);
    }
    if (ref.mounted) _applyTrust();
  }

  void acknowledgeAlert(String deviceId) {
    state = state.copyWith(
      alerts: [
        for (final a in state.alerts)
          a.deviceId == deviceId ? a.copyWith(acknowledged: true) : a,
      ],
    );
  }

  void acknowledgeAll() {
    if (state.unacknowledgedAlertCount == 0) return;
    state = state.copyWith(
      alerts: [for (final a in state.alerts) a.copyWith(acknowledged: true)],
    );
  }

  Set<String> _groupIdsOf(String deviceId) {
    _publishPending();
    for (final g in state.groups) {
      if (g.members.any((m) => m.id == deviceId)) {
        return {for (final m in g.members) m.id};
      }
    }
    return {deviceId};
  }

  /// Raises one alert for [device] if it is new since the baseline, not
  /// trusted, close enough and confirmed (BLE: heard over ≥ 3 s).
  void _maybeAlert(ScannedDeviceModel device) {
    final baseline = state.baselineAt;
    if (baseline == null) return;
    if (_alertedIds.contains(device.id) || state.isTrusted(device.id)) return;
    if (!device.firstSeen.isAfter(baseline)) return;

    final strongEnough = switch (device.transport) {
      DeviceTransport.wifi =>
        device.deviceType == WirelessClassifier.hotspotType &&
            device.rssi >= _hotspotAlertRssi,
      _ => device.rssi >= _alertRssi,
    };
    if (!strongEnough) return;
    if (device.isBle &&
        device.lastSeen.difference(device.firstSeen) < _bleConfirmSpan) {
      return;
    }

    _publishPending();
    for (final g in state.groups) {
      if (!g.members.any((m) => m.id == device.id)) continue;
      final others = g.members.where((m) => m.id != device.id);
      if (others.any((m) => state.isTrusted(m.id))) return;
      if (others.any((m) => _alertedIds.contains(m.id))) {
        // Another address of an already reported device.
        _alertedIds.add(device.id);
        return;
      }
      break;
    }

    _alertedIds.add(device.id);
    state = state.copyWith(
      alerts: [
        NewDeviceAlert(
          deviceId: device.id,
          displayName: device.displayName,
          deviceType: device.deviceType,
          transport: device.transport,
          rssi: device.rssi,
          detectedAt: _now(),
        ),
        ...state.alerts,
      ],
      alertSeq: state.alertSeq + 1,
    );
  }

  // ── List order and selection ─────────────────────────────────────────

  /// Switches between "Stable" and "Nearest first" for this session.
  void setSortMode(ScanSortMode mode) {
    if (mode == state.sortMode) return;
    _nearest.reset();
    state = state.copyWith(sortMode: mode);
    _publish();
  }

  /// Enters multi-select mode, optionally picking [deviceId] first.
  void startSelection([String? deviceId]) {
    state = state.copyWith(isSelecting: true, selectedIds: const {});
    if (deviceId != null) toggleSelected(deviceId);
  }

  /// Picks or unpicks the device (all addresses of its group) for
  /// "Walk & find". Only BLE devices, at most
  /// [ScannerState.maxWalkTargets].
  void toggleSelected(String deviceId) {
    _publishPending();
    final groupIds = _groupIdsOf(deviceId);
    final selected = {...state.selectedIds};
    if (selected.any(groupIds.contains)) {
      selected.removeAll(groupIds);
    } else {
      final device = _live[deviceId];
      if (device == null) return;
      if (!device.isBle) {
        _notify('scan_select_ble_only');
        return;
      }
      if (selected.length >= ScannerState.maxWalkTargets) {
        _notify('scan_select_limit', {'max': '${ScannerState.maxWalkTargets}'});
        return;
      }
      selected.add(deviceId);
    }
    state = state.copyWith(isSelecting: true, selectedIds: selected);
  }

  void cancelSelection() {
    state = state.copyWith(isSelecting: false, selectedIds: const {});
  }

  /// Devices for "Walk & find strongest untrusted"; empty (with a notice)
  /// when there is none.
  List<ScannedDeviceModel> strongestUntrustedTargets() {
    _publishPending();
    final targets = state.strongestUntrusted();
    if (targets.isEmpty) _notify('scan_walk_none');
    return targets;
  }

  // ── Publishing ───────────────────────────────────────────────────────

  /// Publishes soon (coalescing further updates until then).
  void _schedulePublish() {
    _publishTimer ??= Timer(_publishEvery, _publish);
  }

  /// Publishes now if an update is waiting.
  void _publishPending() {
    if (_publishTimer != null) _publish();
  }

  /// The model as shown: BLE signal smoothed.
  ScannedDeviceModel _shown(ScannedDeviceModel d) {
    if (!d.isBle) return d;
    final smoothed = _smoother.valueOf(d.id);
    return smoothed == null ? d : d.copyWith(rssi: smoothed.round());
  }

  bool _isStaleAt(ScannedDeviceModel d, DateTime now) =>
      !d.isConnected &&
      now.difference(d.lastSeen) > (d.isBle ? _staleAfter : _slowStaleAfter);

  /// Publishes the live store: smoothed values, proximity bands, staleness,
  /// sticky groups in the chosen order.
  void _publish() {
    _publishTimer?.cancel();
    _publishTimer = null;
    if (!ref.mounted) return;
    final now = _now();

    final shown = [for (final d in _live.values) _shown(d)]
      ..sort((a, b) => b.firstSeen.compareTo(a.firstSeen));
    for (final d in shown) {
      _bands[d.id] = ProximityBand.next(_bands[d.id], d.rssi);
    }
    _bands.removeWhere((id, _) => !_live.containsKey(id));
    final stale = {
      for (final d in shown)
        if (_isStaleAt(d, now)) d.id,
    };

    final grouped = _grouper.group(
      shown,
      now: now,
      isSilent: (d) => stale.contains(d.id),
    );
    final selected = {
      for (final id in state.selectedIds)
        if (_live.containsKey(id)) id,
    };

    final signature = _signatureOf(grouped);
    if (signature != _groupSignature) {
      _groupSignature = signature;
      _identityVersion++;
    }

    state = state.copyWith(
      identityVersion: _identityVersion,
      devices: shown,
      groups: _ordered(grouped, now),
      staleIds: stale,
      bands: Map.unmodifiable(_bands),
      asOf: now,
      selectedIds: selected,
      togglingIds: {
        for (final id in _presence.togglingIds(now))
          if (_live.containsKey(id)) id,
      },
    );
  }

  /// Presence and signal history of [id] (also after it left), or null.
  DeviceHistory? historyOf(String id) => _presence.historyOf(id);

  int _appearanceOf(ScannedDeviceGroup g) => g.members
      .map((m) => _appearance[m.id] ?? 1 << 30)
      .reduce((a, b) => a < b ? a : b);

  List<ScannedDeviceGroup> _ordered(
    List<ScannedDeviceGroup> groups,
    DateTime now,
  ) {
    final byAppearance = [...groups]
      ..sort((a, b) {
        final c = _appearanceOf(a).compareTo(_appearanceOf(b));
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    if (state.sortMode == ScanSortMode.stable) return byAppearance;

    final byKey = {for (final g in byAppearance) g.id: g};
    final keys = _nearest.order([
      for (final g in byAppearance)
        (
          key: g.id,
          rssi: g.strongestRssi.toDouble(),
          trusted: g.members.any((m) => state.trustedIds.contains(m.id)),
        ),
    ], now);
    return [for (final k in keys) byKey[k]!];
  }

  void _forget(String id) {
    _live.remove(id);
    _appearance.remove(id);
    _smoother.remove(id);
    _bands.remove(id);
  }

  void _forgetAll() {
    _nameLookupTried.clear();
    _presence.clear();
    _live.clear();
    _appearance.clear();
    _smoother.clear();
    _bands.clear();
    _grouper.reset();
    _nearest.reset();
  }

  void _addNew(ScannedDeviceModel device) {
    _appearance[device.id] = _nextAppearance++;
    _live[device.id] = device;
  }

  // ── Scan lifecycle ───────────────────────────────────────────────────

  /// Location off: Android silently returns no BLE results. The scan owner
  /// stays registered so the shared scan resumes once Location is back.
  void _onScanProblem(BleScanError? problem) {
    if (!ref.mounted) return;
    final isOff = problem == BleScanError.locationOff;
    if (isOff == state.isLocationOff) return;
    state = state.copyWith(isLocationOff: isOff);
  }

  /// While Wi-Fi scanning has a problem its old results are dropped, so no
  /// stale hotspot is shown as present.
  void _onWifiProblem(WifiScanProblem? problem) {
    if (!ref.mounted || problem == state.wifiProblem) return;
    state = state.copyWith(
      wifiProblem: problem,
      clearWifiProblem: problem == null,
    );
    if (problem != null) {
      final wifiIds = [
        for (final d in _live.values)
          if (d.transport == DeviceTransport.wifi) d.id,
      ];
      wifiIds.forEach(_forget);
      if (wifiIds.isNotEmpty) _publish();
    }
  }

  /// Opens the system Location settings so the user can turn Location on.
  Future<void> openLocationSettings() async {
    try {
      final opened = await _repository.openLocationSettings();
      if (!opened && ref.mounted) _notify('scan_notice_location_settings');
    } catch (e, st) {
      _logger.warning('Opening Location settings failed', e, st);
      if (ref.mounted) _notify('scan_notice_location_settings');
    }
  }

  /// The permission was permanently denied: only the OS settings can fix it.
  bool get needsAppSettings =>
      state.errorMessage == 'scan_err_permission_permanent';

  Future<void> openAppSettings() async {
    try {
      await _repository.openAppSettings();
    } catch (e, st) {
      _logger.warning('Opening app settings failed', e, st);
    }
  }

  /// Shows a one-off message without touching the blocking scan error.
  void _notify(String key, [Map<String, String> args = const {}]) {
    state = state.copyWith(
      noticeKey: key,
      noticeArgs: args,
      noticeId: state.noticeId + 1,
    );
  }

  void _onBluetoothOn(bool isOn) {
    if (!ref.mounted) return;
    final isOff = !isOn;
    if (isOff == state.isBluetoothOff) return;
    state = state.copyWith(isBluetoothOff: isOff);
    if (isOff && state.isScanning) {
      _stop(keepAdapterListener: true);
      state = state.copyWith(isScanning: false);
    } else if (!isOff) {
      // Bluetooth came back on: resume live scanning automatically.
      toggleScanning(true);
    }
  }

  void toggleRoomBoundaryMode([bool? enabled]) {
    final nextMode = enabled ?? !state.isRoomBoundaryMode;
    state = state.copyWith(isRoomBoundaryMode: nextMode);
  }

  void setRoomSizePreset(RoomSizePreset preset) {
    state = state.copyWith(roomSizePreset: preset);
  }

  Future<void> toggleScanning([bool? enable]) async {
    final shouldScan = enable ?? !state.isScanning;
    if (!shouldScan) {
      _stop(keepAdapterListener: true);
      _publishPending();
      state = state.copyWith(isScanning: false);
      return;
    }
    // The view model, the screen and the adapter listener can all ask to
    // start at once; share one start so permissions are requested only once.
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    if (!await checkPermissions()) {
      if (ref.mounted) state = state.copyWith(isScanning: false);
      return;
    }
    if (!ref.mounted) return;

    _sightingsSub?.cancel();
    _sightingsSub = _repository.sightings().listen(
      _onSighting,
      onError: (Object e, StackTrace st) {
        _logger.warning('BLE scan error', e, st);
        if (ref.mounted) _setScanError(e);
      },
    );
    _evictTimer?.cancel();
    _evictTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _evictStaleDevices();
    });
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(
      _activityEvery,
      (_) => unawaited(recordActivityNow()),
    );
    unawaited(_loadKnownNames());
    _nameLookupsLeft = _maxNameLookups;
    _nameLookupTimer?.cancel();
    _nameLookupTimer = Timer.periodic(
      _nameLookupEvery,
      (_) => unawaited(_lookUpNextName()),
    );

    // Classic and Wi-Fi are extras: if they fail, BLE still runs.
    await _startSlowScans();
    if (!ref.mounted) return;

    try {
      await _repository.startScan();
    } on BleScanException catch (e) {
      if (!ref.mounted) return;
      if (e.code == BleScanError.locationOff) {
        // Not a failure: the owner stays registered and the scan resumes
        // by itself once Location is turned on.
        state = state.copyWith(
          isScanning: true,
          isLocationOff: true,
          clearError: true,
        );
        return;
      }
      _stop(keepAdapterListener: true);
      state = state.copyWith(isScanning: false);
      _setScanError(e);
      return;
    }
    if (ref.mounted) {
      state = state.copyWith(isScanning: true, clearError: true);
    }
  }

  Future<void> _startSlowScans() async {
    if (_repository.isClassicSupported) {
      _classicSub?.cancel();
      _classicSub = _repository.classicSightings().listen(
        _onClassicSighting,
        onError: (Object e, StackTrace st) =>
            _logger.warning('Classic Bluetooth discovery error', e, st),
      );
      try {
        await _repository.startClassicDiscovery();
      } catch (e, st) {
        _logger.warning('Classic Bluetooth discovery did not start', e, st);
      }
    }
    if (_repository.isWifiSupported) {
      _wifiSub?.cancel();
      _wifiSub = _repository.wifiSightings().listen(
        _onWifiScan,
        onError: (Object e, StackTrace st) =>
            _logger.warning('Wi-Fi scan error', e, st),
      );
      try {
        await _repository.startWifiScan();
      } catch (e, st) {
        _logger.warning('Wi-Fi scan did not start', e, st);
      }
    }
  }

  /// Maps a scan failure to a translatable message. Known core messages get
  /// their own key; anything else is shown as reported. Location off is
  /// not an error: it is shown through [ScannerState.isLocationOff].
  void _setScanError(Object e) {
    final text = e is BleScanException ? e.message : '$e';
    final code = e is BleScanException ? e.code : BleScanError.other;
    if (code == BleScanError.locationOff) {
      state = state.copyWith(isLocationOff: true);
    } else if (code == BleScanError.throttled) {
      state = state.copyWith(errorMessage: 'scan_err_throttled');
    } else {
      state = state.copyWith(
        errorMessage: 'scan_err_detail',
        errorArgs: {'detail': text},
      );
    }
  }

  /// Runs every second: devices silent past the gone-after time are
  /// removed; quiet ones are re-published so "last seen Xs ago" counts up.
  void _evictStaleDevices() {
    if (!ref.mounted) return;
    final now = _now();
    final gone = [
      for (final d in _live.values)
        if (!d.isConnected &&
            now.difference(d.lastSeen) >=
                (d.isBle ? _goneAfter : _slowGoneAfter))
          d.id,
    ];
    gone.forEach(_forget);
    _presence.prune(now);
    final anyStale = _live.values.any((d) => _isStaleAt(d, now));
    if (gone.isNotEmpty || anyStale || state.staleIds.isNotEmpty) _publish();
  }

  /// Connects to a device on the inspector's request and reads what it exposes.
  Future<void> probeDeviceConnection(String deviceId) async {
    final target = _live[deviceId];
    if (target == null ||
        !target.isBle ||
        target.isConnected ||
        target.isConnecting) {
      return;
    }

    _replace(deviceId, (d) => d.copyWith(isConnecting: true));
    try {
      final info = await _repository.connect(deviceId);
      if (!ref.mounted) return;
      _replace(
        deviceId,
        (d) => d.copyWith(
          isConnected: true,
          isConnecting: false,
          batteryLevel: info.batteryLevel,
          fullGattName: info.gattName,
        ),
      );
    } catch (e, st) {
      _logger.warning('Connect failed for $deviceId', e, st);
      if (!ref.mounted) return;
      _replace(deviceId, (d) => d.copyWith(isConnecting: false));
      _notify('scan_err_connect_failed', {'name': target.displayName});
    }
  }

  Future<void> disconnectDevice(String deviceId) async {
    try {
      await _repository.disconnect(deviceId);
    } catch (e, st) {
      _logger.warning('Disconnect failed for $deviceId', e, st);
    }
    if (!ref.mounted) return;
    _replace(
      deviceId,
      (d) => d.copyWith(isConnected: false, isConnecting: false),
    );
  }

  Future<void> enableBluetooth() async {
    try {
      await _repository.turnOnBluetooth();
      await toggleScanning(true);
    } catch (e, st) {
      _logger.warning('Turning Bluetooth on failed', e, st);
      if (ref.mounted) _notify('scan_err_enable_bluetooth');
    }
  }

  Future<bool> checkPermissions() async {
    try {
      if (!await _repository.isSupported()) {
        state = state.copyWith(
          errorMessage: 'scan_err_unsupported',
          isBluetoothOff: true,
        );
        return false;
      }

      final permission = await _repository.requestPermissions();
      if (!ref.mounted) return false;
      switch (permission) {
        case AppPermissionStatus.permanentlyDenied:
          state = state.copyWith(errorMessage: 'scan_err_permission_permanent');
          return false;
        case AppPermissionStatus.denied:
          state = state.copyWith(errorMessage: 'scan_err_permission_required');
          return false;
        case AppPermissionStatus.granted:
          break;
      }

      final isOn = await _repository.bluetoothOn().first;
      if (!ref.mounted) return false;
      if (!isOn) {
        state = state.copyWith(
          isBluetoothOff: true,
          errorMessage: 'scan_err_bluetooth_off',
        );
        return false;
      }

      state = state.copyWith(isBluetoothOff: false, clearError: true);
      return true;
    } catch (e, st) {
      _logger.error('Bluetooth permission check failed', e, st);
      if (ref.mounted) {
        state = state.copyWith(
          errorMessage: 'scan_err_check_failed',
          errorArgs: {'detail': '$e'},
        );
      }
      return false;
    }
  }

  // ── Sightings ────────────────────────────────────────────────────────

  void _onSighting(ScannedDeviceModel seen) {
    if (!ref.mounted) return;
    final existing = _live[seen.id];
    final rotatedFrom = existing == null ? _rotatedFrom(seen) : null;
    final previous = existing ?? rotatedFrom;

    final device = _withKnownName(
      previous == null
          ? seen
          : seen.copyWith(
              isConnectable: seen.isConnectable || previous.isConnectable,
              firstSeen: previous.firstSeen,
              isConnected: existing?.isConnected,
              isConnecting: existing?.isConnecting,
              batteryLevel: existing?.batteryLevel,
              fullGattName: existing?.fullGattName,
            ),
    );

    if (rotatedFrom != null) {
      _recordRotation(rotatedFrom.id, seen.id);
      _presence.alias(rotatedFrom.id, seen.id);
      _inheritFromRotated(rotatedFrom.id, seen.id);
      // The new address takes the old card's place in the list.
      final place = _appearance[rotatedFrom.id];
      _forget(rotatedFrom.id);
      _live[seen.id] = device;
      _appearance[seen.id] = place ?? _nextAppearance++;
    } else if (existing == null) {
      _addNew(device);
    } else {
      _live[seen.id] = device;
    }
    _smoother.add(seen.id, seen.rssi);
    _presence.record(seen.id, seen.rssi, _now());

    // Appearing (or replacing) devices show at once; value updates are
    // coalesced.
    if (existing == null) {
      _publish();
    } else {
      _schedulePublish();
    }
    _maybeAlert(_shown(device));
  }

  /// A rotated address keeps its old entry's trust and alert state.
  void _inheritFromRotated(String oldId, String newId) {
    if (_alertedIds.contains(oldId)) _alertedIds.add(newId);
    final selected = state.selectedIds;
    if (selected.contains(oldId)) {
      state = state.copyWith(selectedIds: {...selected, newId});
    }
    if (!state.isTrusted(oldId) || state.isTrusted(newId)) return;
    _localTrusted.add(newId);
    state = state.copyWith(trustedIds: {...state.trustedIds, newId});
    unawaited(_persistTrust(newId));
  }

  Future<void> _persistTrust(String id) async {
    try {
      await ref.read(sessionViewModelProvider.notifier).trustDevice(id);
    } catch (e, st) {
      _logger.warning('Rotated address trust kept in memory only', e, st);
    }
  }

  void _onClassicSighting(ScannedDeviceModel seen) {
    if (!ref.mounted) return;
    final existing = _live[seen.id];
    final device = existing == null
        ? seen
        : seen.copyWith(
            name: seen.name.isEmpty ? existing.name : null,
            deviceType: seen.deviceType == WirelessClassifier.classicOtherType
                ? existing.deviceType
                : null,
            isHighSuspicion: seen.isHighSuspicion || existing.isHighSuspicion,
            firstSeen: existing.firstSeen,
          );
    final named = _withKnownName(device);
    existing == null ? _addNew(named) : _live[named.id] = named;
    _presence.record(seen.id, seen.rssi, _now(), canToggle: false);
    _publish();
    _maybeAlert(named);
  }

  void _onWifiScan(List<ScannedDeviceModel> scan) {
    if (!ref.mounted || scan.isEmpty) return;
    final merged = [
      for (final seen in scan)
        if (_live[seen.id] case final existing?)
          seen.copyWith(firstSeen: existing.firstSeen)
        else
          seen,
    ];
    final now = _now();
    for (final d in merged) {
      _live.containsKey(d.id) ? _live[d.id] = d : _addNew(d);
      _presence.record(d.id, d.rssi, now, canToggle: false);
    }
    _publish();
    for (final d in merged) {
      _maybeAlert(d);
    }
  }

  /// The entry a newly seen address most likely replaced: same name (or,
  /// for nameless devices, same vendor, category and services) and silent
  /// since before [_rotationGap]. Two identical devices that are both
  /// advertising are never merged. BLE only: classic and Wi-Fi addresses
  /// don't rotate.
  ScannedDeviceModel? _rotatedFrom(ScannedDeviceModel seen) {
    if (!seen.isBle) return null;
    final now = _now();
    ScannedDeviceModel? match;
    for (final d in _live.values) {
      if (!d.isBle || d.isConnected || d.isConnecting) continue;
      if (now.difference(d.lastSeen) < _rotationGap) continue;
      final sameIdentity = seen.hasName || d.hasName
          ? seen.name.trim() == d.name.trim()
          : seen.manufacturer == d.manufacturer &&
                seen.manufacturer != 'Generic BLE Hardware' &&
                seen.deviceType == d.deviceType &&
                _sameServices(seen.serviceUuids, d.serviceUuids);
      if (sameIdentity &&
          (match == null || d.lastSeen.isAfter(match.lastSeen))) {
        match = d;
      }
    }
    return match;
  }

  static bool _sameServices(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  /// [d] under the name the OS knows for it, when it advertises none.
  ScannedDeviceModel _withKnownName(ScannedDeviceModel d) {
    if (d.hasName) return d;
    final known = _knownNames[d.id];
    return known == null ? d : d.copyWith(fullGattName: known);
  }

  Future<void> _loadKnownNames() async {
    try {
      final names = await _repository.knownDeviceNames();
      if (!ref.mounted || names.isEmpty) return;
      _knownNames = names;
      var changed = false;
      for (final d in _live.values.toList()) {
        final named = _withKnownName(d);
        if (!identical(named, d)) {
          _live[d.id] = named;
          changed = true;
        }
      }
      if (changed) _publish();
    } catch (e, st) {
      _logger.warning('Reading known device names failed', e, st);
    }
  }

  /// Phones and Apple devices don't reveal a name over a plain connection,
  /// so they aren't worth one.
  static bool _worthNameLookup(ScannedDeviceModel d) =>
      d.isBle &&
      !d.hasName &&
      d.isConnectable &&
      !d.isConnected &&
      !d.isConnecting &&
      d.rssi >= _nameLookupMinRssi &&
      !d.manufacturer.contains('Apple') &&
      !d.deviceType.contains('Smartphone');

  /// Runs one name-lookup step now instead of waiting for the timer.
  @visibleForTesting
  Future<void> lookUpNextNameNow() => _lookUpNextName();

  /// Connects to the strongest nameless nearby device not tried yet, reads
  /// its name and disconnects. One at a time, and never while the user is
  /// connected to something.
  Future<void> _lookUpNextName() async {
    if (_nameLookupId != null || _nameLookupsLeft <= 0) return;
    if (!state.isScanning || state.isLocationOff) return;
    if (_live.values.any((d) => d.isConnected || d.isConnecting)) return;
    ScannedDeviceModel? target;
    for (final d in _live.values) {
      if (_nameLookupTried.contains(d.id) || !_worthNameLookup(d)) continue;
      if (target == null || d.rssi > target.rssi) target = d;
    }
    if (target == null) return;

    final id = target.id;
    _nameLookupTried.add(id);
    _nameLookupsLeft--;
    _nameLookupId = id;
    BleConnectionInfo? info;
    try {
      info = await _repository.connect(id).timeout(_nameLookupTimeout);
    } catch (e) {
      _logger.debug('Name lookup failed for $id: $e');
    } finally {
      // Keep a connection the user made meanwhile.
      if (_live[id]?.isConnected != true) {
        try {
          await _repository.disconnect(id);
        } catch (_) {}
      }
      _nameLookupId = null;
    }
    final name = info?.gattName?.trim() ?? '';
    if (!ref.mounted || name.isEmpty) return;
    _replace(
      id,
      (d) => d.copyWith(
        fullGattName: name,
        batteryLevel: info?.batteryLevel ?? d.batteryLevel,
      ),
    );
  }

  void _replace(
    String id,
    ScannedDeviceModel Function(ScannedDeviceModel) update,
  ) {
    final d = _live[id];
    if (d == null) return;
    _live[id] = update(d);
    _publish();
  }

  void clearResults() {
    _forgetAll();
    state = state.copyWith(isSelecting: false, selectedIds: const {});
    _publish();
  }

  void _stop({bool keepAdapterListener = false}) {
    _evictTimer?.cancel();
    _evictTimer = null;
    _activityTimer?.cancel();
    _activityTimer = null;
    _nameLookupTimer?.cancel();
    _nameLookupTimer = null;
    _sightingsSub?.cancel();
    _sightingsSub = null;
    _classicSub?.cancel();
    _classicSub = null;
    _wifiSub?.cancel();
    _wifiSub = null;
    _repository.stopScan();
    if (_repository.isClassicSupported) {
      _repository.stopClassicDiscovery().catchError(
        (Object e, StackTrace st) =>
            _logger.warning('Stopping classic discovery failed', e, st),
      );
    }
    if (_repository.isWifiSupported) {
      _repository.stopWifiScan().catchError(
        (Object e, StackTrace st) =>
            _logger.warning('Stopping Wi-Fi scan failed', e, st),
      );
    }
    if (!keepAdapterListener) {
      _adapterSub?.cancel();
      _adapterSub = null;
      _problemSub?.cancel();
      _problemSub = null;
      _wifiProblemSub?.cancel();
      _wifiProblemSub = null;
    }
  }
}

/// Auto-disposed so the scans stop once the dashboard and scanner screens
/// are gone (e.g. after End Exam).
final scannerViewModelProvider =
    NotifierProvider.autoDispose<ScannerViewModel, ScannerState>(
      ScannerViewModel.new,
    );
