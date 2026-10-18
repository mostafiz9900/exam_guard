import 'package:exam_guard/features/scanner/model/scanned_device_group.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// Manufacturer value used when the vendor is unknown. Unknown vendors
/// are never grouped: too many unrelated gadgets look alike.
const String _genericManufacturer = 'Generic BLE Hardware';

/// Signals this close in strength may come from the same radio.
const int groupRssiWindowDb = 6;

/// Addresses a phone advertises together appear within this window.
const Duration groupFirstSeenWindow = Duration(seconds: 10);

/// True when [a] and [b] are most likely two addresses of one device:
/// both nameless, same known vendor, same category, identical service
/// UUIDs, similar signal strength and first seen at about the same time.
/// Named devices and classic Bluetooth / Wi-Fi results (fixed addresses)
/// are never grouped.
bool likelySameDevice(ScannedDeviceModel a, ScannedDeviceModel b) {
  if (a.id == b.id) return true;
  if (!sameFingerprint(a, b)) return false;
  if ((a.rssi - b.rssi).abs() > groupRssiWindowDb) return false;
  return a.firstSeen.difference(b.firstSeen).abs() <= groupFirstSeenWindow;
}

/// The identity part of [likelySameDevice]: nameless BLE, same known
/// vendor, category and services. Signal and timing are not compared.
bool sameFingerprint(ScannedDeviceModel a, ScannedDeviceModel b) {
  if (a.id == b.id) return true;
  if (!a.isBle || !b.isBle) return false;
  if (a.hasName || b.hasName) return false;
  if (a.manufacturer != b.manufacturer) return false;
  if (a.manufacturer == _genericManufacturer) return false;
  if (a.deviceType != b.deviceType) return false;
  return _sameServiceSet(a.serviceUuids, b.serviceUuids);
}

bool _sameServiceSet(List<String> a, List<String> b) {
  final sa = a.map((u) => u.toUpperCase()).toSet();
  final sb = b.map((u) => u.toUpperCase()).toSet();
  return sa.length == sb.length && sa.containsAll(sb);
}

/// Groups addresses that likely belong to one device. Every input device
/// ends up in exactly one group, so no data is lost.
///
/// A device joins a group only if it matches every member already in it,
/// so a chain of near-matches never pulls in something very different.
/// The earliest-seen member (then lowest id) is the group's primary, which
/// keeps the card stable while signals change. Groups keep the order of
/// their primaries in [devices].
List<ScannedDeviceGroup> groupLikelySameDevices(
  List<ScannedDeviceModel> devices,
) {
  if (devices.length < 2) {
    return [
      for (final d in devices) ScannedDeviceGroup([d]),
    ];
  }

  final ordered = [...devices]
    ..sort((a, b) {
      final byTime = a.firstSeen.compareTo(b.firstSeen);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });

  final clusters = <List<ScannedDeviceModel>>[];
  for (final device in ordered) {
    List<ScannedDeviceModel>? home;
    if (!device.hasName) {
      for (final cluster in clusters) {
        if (cluster.every((m) => likelySameDevice(m, device))) {
          home = cluster;
          break;
        }
      }
    }
    if (home != null) {
      home.add(device);
    } else {
      clusters.add([device]);
    }
  }

  final position = {for (var i = 0; i < devices.length; i++) devices[i].id: i};
  clusters.sort(
    (a, b) => position[a.first.id]!.compareTo(position[b.first.id]!),
  );
  return [for (final c in clusters) ScannedDeviceGroup(List.unmodifiable(c))];
}

/// Grouped members split only when their signals differ by more than this…
const int groupSplitRssiDb = 12;

/// …for at least this long.
const Duration groupSplitAfter = Duration(seconds: 10);

int _byFirstSeen(ScannedDeviceModel a, ScannedDeviceModel b) {
  final byTime = a.firstSeen.compareTo(b.firstSeen);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// [groupLikelySameDevices] with memory, so cards don't merge and split as
/// signals drift across the 6 dB window.
///
/// - Addresses grouped once stay together while both are live, even when
///   their signals drift apart. They split only when they are more than
///   [groupSplitRssiDb] apart for [groupSplitAfter], when one goes silent
///   ([isSilent]) or when their fingerprint changes (e.g. a name appears).
/// - New addresses (and singles first seen less than
///   [groupFirstSeenWindow] ago) join a group only under the strict
///   [likelySameDevice] rule against every member.
/// - Groups that are already established never merge with each other.
///
/// Returned groups are in no particular order; members are earliest first.
class StickyDeviceGrouper {
  List<List<String>> _clusters = const [];
  Map<String, DateTime> _farSince = {};

  void reset() {
    _clusters = const [];
    _farSince = {};
  }

  List<ScannedDeviceGroup> group(
    List<ScannedDeviceModel> devices, {
    required DateTime now,
    required bool Function(ScannedDeviceModel device) isSilent,
  }) {
    final byId = {for (final d in devices) d.id: d};
    final farSince = <String, DateTime>{};

    bool staysWith(ScannedDeviceModel a, ScannedDeviceModel b) {
      if (!sameFingerprint(a, b)) return false;
      if (isSilent(a) || isSilent(b)) return false;
      final key = a.id.compareTo(b.id) < 0
          ? '${a.id}|${b.id}'
          : '${b.id}|${a.id}';
      if ((a.rssi - b.rssi).abs() <= groupSplitRssiDb) return true;
      final since = _farSince[key] ?? now;
      farSince[key] = since;
      return now.difference(since) < groupSplitAfter;
    }

    final clusters = <List<ScannedDeviceModel>>[];
    final placed = <String>{};

    // 1. Keep earlier groups together where they still hold.
    for (final previous in _clusters) {
      final members = [for (final id in previous) ?byId[id]]
        ..sort(_byFirstSeen);
      if (members.isEmpty) continue;
      // A young single may still join a group under the strict rule.
      if (members.length == 1 &&
          now.difference(members.single.firstSeen) < groupFirstSeenWindow) {
        continue;
      }
      final parts = <List<ScannedDeviceModel>>[];
      for (final m in members) {
        final home = parts
            .where((p) => p.every((o) => staysWith(o, m)))
            .firstOrNull;
        home != null ? home.add(m) : parts.add([m]);
      }
      clusters.addAll(parts);
      placed.addAll(members.map((m) => m.id));
    }

    // 2. New addresses join under the strict rule, or start a group.
    final fresh = [
      for (final d in devices)
        if (!placed.contains(d.id)) d,
    ]..sort(_byFirstSeen);
    for (final d in fresh) {
      List<ScannedDeviceModel>? home;
      if (!d.hasName && !isSilent(d)) {
        home = clusters
            .where(
              (c) => c.every((m) => !isSilent(m) && likelySameDevice(m, d)),
            )
            .firstOrNull;
      }
      if (home != null) {
        home
          ..add(d)
          ..sort(_byFirstSeen);
      } else {
        clusters.add([d]);
      }
    }

    _farSince = farSince;
    _clusters = [
      for (final c in clusters) [for (final m in c) m.id],
    ];
    return [for (final c in clusters) ScannedDeviceGroup(List.unmodifiable(c))];
  }
}
