import 'package:exam_guard/features/action_log/model/incident_categories.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:flutter_test/flutter_test.dart';

ScannedDeviceModel _device(DeviceTransport transport, String type) =>
    ScannedDeviceModel(
      id: 'AA:BB:CC:DD:EE:FF',
      name: 'X',
      rssi: -60,
      deviceType: type,
      transport: transport,
      lastSeen: DateTime(2026),
      firstSeen: DateTime(2026),
    );

void main() {
  test('Wi-Fi results map to Wi-Fi Hotspot', () {
    expect(
      IncidentCategory.forDevice(_device(DeviceTransport.wifi, 'Network')),
      'Wi-Fi Hotspot',
    );
  });

  test('classic audio maps to Classic Bluetooth Earpiece', () {
    expect(
      IncidentCategory.forDevice(
        _device(DeviceTransport.classic, 'Smart Earpiece / Audio'),
      ),
      'Classic Bluetooth Earpiece',
    );
    expect(
      IncidentCategory.forDevice(_device(DeviceTransport.classic, 'Phone')),
      'Bluetooth Device',
    );
  });

  test('BLE devices map to Bluetooth Device unless they are hotspots', () {
    expect(
      IncidentCategory.forDevice(
        _device(DeviceTransport.ble, 'Smart Earpiece / Audio'),
      ),
      'Bluetooth Device',
    );
    expect(
      IncidentCategory.forDevice(
        _device(DeviceTransport.ble, 'Wi-Fi Hotspot / Mobile AP'),
      ),
      'Wi-Fi Hotspot',
    );
  });

  test('an explicit category wins over the device default', () {
    final wifi = _device(DeviceTransport.wifi, 'Network');
    expect(
      IncidentCategory.initial(category: 'Magnetic Anomaly', device: wifi),
      'Magnetic Anomaly',
    );
    expect(
      IncidentCategory.initial(category: ' ', device: wifi),
      'Wi-Fi Hotspot',
    );
    expect(IncidentCategory.initial(), 'Bluetooth Device');
  });

  test('every stored category has a label key', () {
    expect(IncidentCategory.labelKeys.keys, contains('Wi-Fi Hotspot'));
    expect(
      IncidentCategory.labelKeys.keys,
      contains('Classic Bluetooth Earpiece'),
    );
  });
}
