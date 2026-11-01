import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/utils/app_brand.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';
import 'package:exam_guard/features/hall_map/model/hall_locator.dart';
import 'package:exam_guard/features/hall_map/repository/hall_map_repository.dart';
import 'package:exam_guard/features/radar/view_model/seat_sweep_view_model.dart';
import 'package:exam_guard/features/scanner/model/distance_estimate.dart';
import 'package:exam_guard/features/scanner/model/room_equipment.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

/// Node placements on the current room's seat map (node id → row, col).
class HallMapViewModel extends Notifier<Map<String, (int, int)>> {
  late HallMapRepository _repo;
  late AppLogger _logger;
  late String _room;

  @override
  Map<String, (int, int)> build() {
    _repo = ref.watch(hallMapRepositoryProvider);
    _logger = ref.watch(appLoggerProvider);
    _room = ref.watch(
      sessionViewModelProvider.select((s) => s?.roomNumber ?? ''),
    );
    return _repo.placements(_room);
  }

  /// Puts [nodeId] at a seat. A node already there moves off it (one node
  /// per seat). Returns false when it could not be saved.
  Future<bool> place(String nodeId, int row, int col) => _save({
    for (final e in state.entries)
      if (e.key != nodeId && e.value != (row, col)) e.key: e.value,
    nodeId: (row, col),
  });

  Future<bool> remove(String nodeId) => _save({
    for (final e in state.entries)
      if (e.key != nodeId) e.key: e.value,
  });

  Future<bool> _save(Map<String, (int, int)> next) async {
    try {
      await _repo.save(_room, next);
    } on StorageException catch (e, st) {
      _logger.warning('Hall map placement not saved', e, st);
      return false;
    }
    if (ref.mounted) state = next;
    return true;
  }

  /// Sets the exam's seat layout from the inline form. Returns the
  /// translation key of the problem, or null when saved.
  Future<String?> setSeatLayout(String rows, String cols) async {
    final draft = SeatLayoutDraft.parse(rows, cols);
    if (!draft.isValid) return draft.errorKey;
    try {
      await ref
          .read(sessionViewModelProvider.notifier)
          .setSeatLayout(rows: draft.rows!, cols: draft.cols!);
      return null;
    } catch (e, st) {
      _logger.warning('Seat layout not saved', e, st);
      return 'sweep_layout_save_failed';
    }
  }
}

final hallMapViewModelProvider =
    NotifierProvider.autoDispose<HallMapViewModel, Map<String, (int, int)>>(
      HallMapViewModel.new,
    );

// ── What the map shows ─────────────────────────────────────────────────────

/// A sensor node and where it sits, if placed.
@immutable
class MapNode {
  const MapNode({required this.member, required this.isLive, this.seat});

  final HallMember member;
  final bool isLive;

  /// Zero-based (row, col), or null while not placed.
  final (int, int)? seat;
}

/// One node hearing a device.
@immutable
class MapReading {
  const MapReading({
    required this.node,
    required this.rssi,
    required this.meters,
  });

  final HallMember node;
  final int rssi;
  final double meters;
}

/// A suspicious device placed on the map.
@immutable
class LocatedDevice {
  const LocatedDevice({
    required this.device,
    required this.result,
    required this.readings,
    required this.isAlert,
  });

  /// As heard by the strongest node.
  final ScannedDeviceModel device;
  final LocatorResult result;

  /// Strongest first.
  final List<MapReading> readings;

  /// A new-device alert was raised for it.
  final bool isAlert;
}

@immutable
class HallMapData {
  const HallMapData({
    required this.rows,
    required this.cols,
    required this.nodes,
    required this.devices,
    required this.pathLoss,
    required this.isCalibrated,
  });

  final int rows;
  final int cols;
  final List<MapNode> nodes;
  final List<LocatedDevice> devices;

  /// Path-loss exponent used (learnt from the nodes when [isCalibrated]).
  final double pathLoss;
  final bool isCalibrated;

  bool get hasLayout => rows > 0 && cols > 0;
  int get placedLive => nodes.where((n) => n.isLive && n.seat != null).length;
  bool get hasUnplaced => nodes.any((n) => n.seat == null);
}

/// The live hall map: nodes on their seats and every suspicious device
/// they hear, placed by [HallLocator]. Recomputed as sightings arrive.
final hallMapProvider = Provider.autoDispose<HallMapData>((ref) {
  final session = ref.watch(sessionViewModelProvider);
  final hall = ref.watch(hallViewModelProvider);
  final placements = ref.watch(hallMapViewModelProvider);
  // Never start a scan just for the map; use trust only if it is running.
  final trusted = ref.exists(scannerViewModelProvider)
      ? ref.watch(scannerViewModelProvider.select((s) => s.trustedIds))
      : const <String>{};
  return buildHallMap(
    rows: session?.seatRows ?? 0,
    cols: session?.seatCols ?? 0,
    hall: hall,
    placements: placements,
    trusted: trusted,
  );
});

/// Pure part of [hallMapProvider], for tests.
@visibleForTesting
HallMapData buildHallMap({
  required int rows,
  required int cols,
  required HallState hall,
  required Map<String, (int, int)> placements,
  Set<String> trusted = const {},
  int maxDevices = 30,
}) {
  final live = {
    for (final m in hall.members)
      if (m.kind == HallMemberKind.node) m.id: m,
  };
  (int, int)? onMap((int, int)? s) =>
      s != null && s.$1 < rows && s.$2 < cols ? s : null;
  final nodes = [
    for (final m in live.values)
      MapNode(member: m, isLive: true, seat: onMap(placements[m.id])),
    for (final o in hall.offlineNodes)
      if (!live.containsKey(o.member.id))
        MapNode(
          member: o.member,
          isLive: false,
          seat: onMap(placements[o.member.id]),
        ),
  ];
  final at = <String, MapPoint>{
    for (final n in nodes)
      if (n.isLive && n.seat != null)
        n.member.id: MapPoint.seat(n.seat!.$1, n.seat!.$2),
  };

  // Nodes hear each other's advertised names: known distance + RSSI.
  final byName = {for (final id in at.keys) live[id]!.name: id};
  final pairs = <({double meters, int rssi})>[];
  for (final r in hall.remoteDevices) {
    final from = at[r.sourceId];
    final other = byName[r.device.name];
    if (from == null || other == null || other == r.sourceId) continue;
    pairs.add((
      meters: from.distanceTo(at[other]!) * HallLocator.seatMeters,
      rssi: r.device.rssi,
    ));
  }
  final learnt = HallLocator.calibrate(pairs);
  final pathLoss = learnt ?? DistanceEstimate.defaultPathLoss;

  final alerted = {
    for (final a in hall.remoteAlerts)
      if (live.containsKey(a.sourceId) || at.containsKey(a.sourceId))
        a.alert.deviceId,
  };
  final heard = <String, List<({HallMember node, ScannedDeviceModel d})>>{};
  for (final r in hall.remoteDevices) {
    if (!at.containsKey(r.sourceId)) continue;
    final d = r.device;
    if (AppBrand.isNodeName(d.name)) continue;
    if (trusted.contains(d.id) || isRoomEquipment(d)) continue;
    (heard[d.id] ??= []).add((node: live[r.sourceId]!, d: d));
  }

  final devices = <LocatedDevice>[];
  if (rows > 0 && cols > 0) {
    for (final e in heard.entries) {
      final list = [...e.value]..sort((a, b) => b.d.rssi.compareTo(a.d.rssi));
      final result = HallLocator.locate(
        [
          for (final x in list)
            LocatorReading(
              nodeId: x.node.id,
              at: at[x.node.id]!,
              rssi: x.d.rssi,
            ),
        ],
        rows: rows,
        cols: cols,
        pathLoss: pathLoss,
      );
      if (result == null) continue;
      devices.add(
        LocatedDevice(
          device: list.first.d,
          result: result,
          readings: [
            for (final x in list)
              MapReading(
                node: x.node,
                rssi: x.d.rssi,
                meters: DistanceEstimate.meters(x.d.rssi, n: pathLoss),
              ),
          ],
          isAlert: alerted.contains(e.key),
        ),
      );
    }
  }
  devices.sort((a, b) {
    if (a.isAlert != b.isAlert) return a.isAlert ? -1 : 1;
    final c = b.result.confidence.index.compareTo(a.result.confidence.index);
    if (c != 0) return c;
    return b.device.rssi.compareTo(a.device.rssi);
  });

  return HallMapData(
    rows: rows,
    cols: cols,
    nodes: List.unmodifiable(nodes),
    devices: List.unmodifiable(devices.take(maxDevices)),
    pathLoss: pathLoss,
    isCalibrated: learnt != null,
  );
}
