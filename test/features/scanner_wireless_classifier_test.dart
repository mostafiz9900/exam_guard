import 'package:exam_guard/core/services/classic_bluetooth/i_classic_bluetooth_service.dart';
import 'package:exam_guard/core/services/wifi/i_wifi_scan_service.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/repository/scanner_repository.dart';
import 'package:exam_guard/features/scanner/repository/wireless_classifier.dart';
import 'package:exam_guard/features/scanner/view_model/device_filter.dart';
import 'package:exam_guard/features/scanner/view_model/device_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

typedef C = WirelessClassifier;

void main() {
  group('classic device class', () {
    String type({int? major, int? cls, String name = ''}) =>
        C.classicDeviceType(
          name: name,
          manufacturer: ScannedDeviceModel.genericBluetoothManufacturer,
          majorDeviceClass: major,
          deviceClass: cls,
        );

    test('major classes map to scanner categories', () {
      expect(type(major: 0x0400, cls: 0x0414), C.audioType);
      expect(type(major: 0x0200, cls: 0x020C), C.phoneType);
      expect(type(major: 0x0700, cls: 0x0704), C.wearableType);
      expect(type(major: 0x0100, cls: 0x010C), C.computerType);
    });

    test('major class is derived from the full class when missing', () {
      expect(type(cls: 0x0404), C.audioType);
      expect(type(cls: 0x020C), C.phoneType);
    });

    test('unknown class falls back to name heuristics', () {
      expect(type(major: 0x1F00, name: 'TWS Earbuds'), C.audioType);
      expect(type(name: 'Galaxy A54'), C.phoneType);
      expect(type(major: 0x0500, name: 'Keyboard K380'), C.classicOtherType);
    });

    test('headset, hands-free and headphones are spy-earpiece classes', () {
      expect(C.isSpyEarpieceClass(0x0404), isTrue);
      expect(C.isSpyEarpieceClass(0x0408), isTrue);
      expect(C.isSpyEarpieceClass(0x0418), isTrue);
      // Service bits above 0x1FFF are ignored.
      expect(C.isSpyEarpieceClass(0x240404), isTrue);
      expect(C.isSpyEarpieceClass(0x0414), isFalse); // loudspeaker
      expect(C.isSpyEarpieceClass(0x020C), isFalse);
      expect(C.isSpyEarpieceClass(null), isFalse);
    });

    test('a classic record becomes a classic device keyed by MAC', () {
      final d = ScannerRepository.classicToDevice(
        ClassicBtRecord(
          address: '00:11:22:33:44:55',
          name: '',
          rssi: -60,
          majorDeviceClass: 0x0400,
          deviceClass: 0x0404,
          timestamp: DateTime(2026),
        ),
      );
      expect(d.id, '00:11:22:33:44:55');
      expect(d.transport, DeviceTransport.classic);
      expect(d.isBle, isFalse);
      expect(d.deviceType, C.audioType);
      expect(d.isHighSuspicion, isTrue);
      expect(d.manufacturer, ScannedDeviceModel.genericBluetoothManufacturer);
      expect(d.displayName, 'Wireless Earpiece (44:55)');
      expect(DeviceFilter.audioDevices.matches(d), isTrue);
    });
  });

  group('Wi-Fi hotspot SSIDs', () {
    for (final ssid in [
      'AndroidAP_5521',
      "Rahim's iPhone",
      'Rahim’s iPhone',
      'iPhone',
      'Galaxy A54 1F2C',
      'Redmi Note 12',
      'POCO X5',
      'OPPO A78',
      'vivo Y21',
      'realme C55',
      'Infinix HOT 30',
      'TECNO SPARK 10',
      'itel A70',
      'Xiaomi 13T',
      'HUAWEI P30',
      'Honor X8',
      'Nokia G21',
      'DIRECT-ab-Galaxy S23',
      'My Hotspot',
      'tethering',
      'Mobile Data',
    ]) {
      test('"$ssid" is a phone hotspot', () {
        expect(C.isPhoneHotspotSsid(ssid), isTrue);
        expect(C.wifiDeviceType(ssid, '10:20:30:40:50:60'), C.hotspotType);
      });
    }

    for (final ssid in [
      'School_Staff',
      'eduroam',
      'TP-Link_8A2C',
      'Tenda_5G',
      'DIRECT-7F-HP LaserJet Pro',
      'DIRECT-29-HP Smart Tank 580',
      '',
    ]) {
      test('"$ssid" is not a phone hotspot name', () {
        expect(C.isPhoneHotspotSsid(ssid), isFalse);
      });
    }
  });

  group('locally administered BSSID', () {
    test('second hex digit 2, 6, A or E', () {
      expect(C.isLocallyAdministeredMac('02:11:22:33:44:55'), isTrue);
      expect(C.isLocallyAdministeredMac('A6:11:22:33:44:55'), isTrue);
      expect(C.isLocallyAdministeredMac('da:11:22:33:44:55'), isTrue);
      expect(C.isLocallyAdministeredMac('fe:11:22:33:44:55'), isTrue);
      expect(C.isLocallyAdministeredMac('00:11:22:33:44:55'), isFalse);
      expect(C.isLocallyAdministeredMac('F4:11:22:33:44:55'), isFalse);
      expect(C.isLocallyAdministeredMac('garbage'), isFalse);
    });

    test('randomized BSSID with a neutral name is a hotspot', () {
      expect(C.wifiDeviceType('Anything', '6A:11:22:33:44:55'), C.hotspotType);
      expect(C.wifiDeviceType('', '6A:11:22:33:44:55'), C.hotspotType);
    });

    test('randomized BSSID of known infrastructure is an access point', () {
      expect(
        C.wifiDeviceType('School_Guest', '6A:11:22:33:44:55'),
        C.accessPointType,
      );
    });

    test('virtual BSSID of a router in the same scan is an access point', () {
      expect(
        C.wifiDeviceType(
          'Hall-3',
          '02:AB:CD:EF:01:23',
          scanBssids: const ['00:AB:CD:EF:01:20', '02:AB:CD:EF:01:23'],
        ),
        C.accessPointType,
      );
    });

    test('a fixed router is an access point', () {
      expect(
        C.wifiDeviceType('ExamHall', '00:11:22:33:44:55'),
        C.accessPointType,
      );
    });
  });

  test('Wi-Fi records become wifi devices with prefixed ids', () {
    final at = DateTime(2026);
    final devices = ScannerRepository.wifiToDevices([
      WifiNetworkRecord(
        ssid: 'AndroidAP_1',
        bssid: 'aa:bb:cc:dd:ee:ff',
        rssi: -55,
        frequencyMhz: 2437,
        capabilities: '[WPA2-PSK-CCMP][ESS]',
        timestamp: at,
      ),
      WifiNetworkRecord(
        ssid: 'School',
        bssid: '00:11:22:33:44:55',
        rssi: -70,
        frequencyMhz: 5180,
        capabilities: '[WPA2-PSK-CCMP][ESS]',
        timestamp: at,
      ),
    ]);
    expect(devices.map((d) => d.id), [
      'wifi:AA:BB:CC:DD:EE:FF',
      'wifi:00:11:22:33:44:55',
    ]);
    expect(devices.first.address, 'AA:BB:CC:DD:EE:FF');
    expect(devices.first.transport, DeviceTransport.wifi);
    expect(devices.first.manufacturer, 'Wi-Fi');
    expect(devices.first.deviceType, C.hotspotType);
    expect(devices.last.deviceType, C.accessPointType);
    expect(DeviceFilter.wifiHotspots.matches(devices.first), isTrue);
    expect(DeviceFilter.wifiHotspots.matches(devices.last), isFalse);
  });

  test('nameless Wi-Fi / classic results are never grouped', () {
    final at = DateTime(2026);
    ScannedDeviceModel wifi(String id) => ScannedDeviceModel(
      id: id,
      name: '',
      manufacturer: 'Wi-Fi',
      deviceType: C.hotspotType,
      rssi: -60,
      lastSeen: at,
      firstSeen: at,
      transport: DeviceTransport.wifi,
    );
    expect(
      groupLikelySameDevices([wifi('wifi:1'), wifi('wifi:2')]),
      hasLength(2),
    );
  });
}
