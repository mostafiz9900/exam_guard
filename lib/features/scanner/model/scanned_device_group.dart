import 'package:flutter/foundation.dart';

import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// One physical device as best the scanner can tell. Phones advertise
/// several random addresses at once, so one handset can show up as a few
/// nameless entries with the same fingerprint. Those are grouped here;
/// every address stays in [members] so nothing is dropped.
@immutable
class ScannedDeviceGroup {
  const ScannedDeviceGroup(this.members) : assert(members.length > 0);

  /// The first member is the primary: shown on the card, used by filters.
  final List<ScannedDeviceModel> members;

  ScannedDeviceModel get primary => members.first;

  String get id => primary.id;

  /// True when several addresses are believed to be one device.
  bool get isGrouped => members.length > 1;

  /// Members other than [primary].
  List<ScannedDeviceModel> get others => members.sublist(1);

  /// Strongest current signal among the members.
  int get strongestRssi =>
      members.map((m) => m.rssi).reduce((a, b) => a > b ? a : b);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedDeviceGroup &&
          other.members.length == members.length &&
          _sameIds(other.members, members);

  static bool _sameIds(List<ScannedDeviceModel> a, List<ScannedDeviceModel> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(members.map((m) => m.id));

  @override
  String toString() =>
      'ScannedDeviceGroup(${members.map((m) => m.id).join(', ')})';
}
