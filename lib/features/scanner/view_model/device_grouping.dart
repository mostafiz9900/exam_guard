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
/// Named devices are never grouped.
bool likelySameDevice(ScannedDeviceModel a, ScannedDeviceModel b) {
  if (a.id == b.id) return true;
  if (a.hasName || b.hasName) return false;
  if (a.manufacturer != b.manufacturer) return false;
  if (a.manufacturer == _genericManufacturer) return false;
  if (a.deviceType != b.deviceType) return false;
  if (!_sameServiceSet(a.serviceUuids, b.serviceUuids)) return false;
  if ((a.rssi - b.rssi).abs() > groupRssiWindowDb) return false;
  return a.firstSeen.difference(b.firstSeen).abs() <= groupFirstSeenWindow;
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
