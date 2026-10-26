// Covert earpiece / induction loop names are recognised and flagged red;
// ordinary devices are not.

import 'package:exam_guard/core/services/classic_bluetooth/i_classic_bluetooth_service.dart';
import 'package:exam_guard/features/scanner/repository/bluetooth_device_inspector.dart';
import 'package:exam_guard/features/scanner/repository/scanner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loop / spy / nano / hands-free names match', () {
    for (final n in [
      'Neckloop BT',
      'NECK LOOP 2',
      'neck-loop',
      'BT Loop',
      'Induction Earpiece',
      'Spy Earpiece',
      'Nano Ear',
      'Handsfree-X1',
      'Hands Free Kit',
      'HANDS-FREE',
    ]) {
      expect(BluetoothDeviceInspector.isSpyEarpieceName(n), isTrue, reason: n);
    }
  });

  test('ordinary names do not match', () {
    for (final n in [
      '',
      'Loopy Speaker',
      'Arduino Nano 33 BLE',
      'iPod nano',
      'Spyder Mouse',
      'Galaxy Buds2',
      'Mi Band 7',
      'Nanoleaf Shapes',
    ]) {
      expect(BluetoothDeviceInspector.isSpyEarpieceName(n), isFalse, reason: n);
    }
  });

  test('a loop is categorised as an earpiece', () {
    expect(
      BluetoothDeviceInspector.resolveDeviceType(
        'Neckloop',
        'Generic',
        const [],
      ),
      contains('Audio'),
    );
  });

  test('classic results: loop name flags high suspicion', () {
    ClassicBtRecord rec(String name) => ClassicBtRecord(
      address: 'AA:BB:CC:DD:EE:FF',
      name: name,
      rssi: -60,
      majorDeviceClass: null,
      deviceClass: null,
      timestamp: DateTime(2026),
    );
    expect(
      ScannerRepository.classicToDevice(rec('Spy Loop')).isHighSuspicion,
      isTrue,
    );
    expect(
      ScannerRepository.classicToDevice(rec('JBL Flip')).isHighSuspicion,
      isFalse,
    );
  });
}
