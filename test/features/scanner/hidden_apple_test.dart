// iOS strips Apple devices' advertisements completely. Such devices are
// labelled as Apple devices (they may be AirPods), never grouped together,
// and shown by the audio filter.

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/device_filter.dart';
import 'package:exam_guard/features/scanner/view_model/device_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

ScannedDeviceModel _hidden(String id, int rssi, DateTime at) =>
    ScannedDeviceModel(
      id: id,
      name: '',
      manufacturer: 'Apple Inc.',
      deviceType: ScannedDeviceModel.appleHiddenType,
      rssi: rssi,
      isConnectable: false,
      lastSeen: at,
      firstSeen: at,
    );

void main() {
  final now = DateTime(2026, 10, 25, 10);

  test('two hidden Apple devices at the same strength stay separate', () {
    final a = _hidden('A', -41, now);
    final b = _hidden('B', -41, now);
    expect(likelySameDevice(a, b), isFalse);
    expect(groupLikelySameDevices([a, b]), hasLength(2));
  });

  test(
    'labelled as an Apple device and matched by audio and phone filters',
    () {
      final d = _hidden('AA:BB:CC:DD:EE:01', -45, now);
      expect(d.displayName, startsWith('Apple Device'));
      expect(DeviceFilter.audioDevices.matches(d), isTrue);
      expect(DeviceFilter.smartphones.matches(d), isTrue);
      expect(DeviceFilter.wifiHotspots.matches(d), isFalse);
    },
  );

  test('scan records are not hidden unless the OS says so', () {
    final r = BleScanRecord(
      id: 'X',
      name: '',
      rssi: -60,
      txPower: null,
      isConnectable: false,
      serviceUuids: const [],
      manufacturerData: const {},
      timestamp: now,
    );
    expect(r.isPayloadHidden, isFalse);
  });
}
