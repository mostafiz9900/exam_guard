/// Helper inspector to resolve MAC OUI vendor and BLE advertisement metadata.
class BluetoothDeviceInspector {
  BluetoothDeviceInspector._();

  /// Known Bluetooth SIG Company Identifiers
  static const Map<int, String> _bleCompanyMap = {
    0x004C: 'Apple Inc.',
    0x0075: 'Samsung Electronics',
    0x0006: 'Microsoft',
    0x00E0: 'Google',
    0x02D0: 'Google LLC',
    0x000A: 'Qualcomm',
    0x0059: 'Nordic Semiconductor (Custom BLE)',
    0x0087: 'Garmin International',
    0x01AB: 'Xiaomi Inc.',
    0x000D: 'Texas Instruments',
    0x02E5: 'Realtek Audio',
    0x0157: 'Anker Soundcore',
    0x009E: 'Bose Corporation',
    0x0030: 'Sony Corporation',
    0x0002: 'Intel Corp.',
    0x000F: 'Broadcom',
    0x00D2: 'Dialog Semiconductor',
    0x0177: 'Baseus Audio',
    0x038F: 'JBL / Harman International',
    0x0375: 'OnePlus / Oppo',
    0x027D: 'Huawei Technologies',
    0x0180: 'Huami / Amazfit',
  };

  /// Common MAC Address OUI prefixes (First 6 HEX digits)
  static const Map<String, String> _macOuiMap = {
    // Apple
    'FC58FA': 'Apple Inc.',
    '004C11': 'Apple Inc.',
    '001CB3': 'Apple Inc.',
    '0026BB': 'Apple Inc.',
    '001E85': 'Apple Inc.',
    '040CCE': 'Apple Inc.',
    '14109F': 'Apple Inc.',
    'F82793': 'Apple Inc.',
    'ACDE48': 'Apple AirPods / Beats',

    // Samsung
    '001A7D': 'Samsung Electronics',
    '0021D2': 'Samsung Electronics',
    '0023D7': 'Samsung Electronics',
    '0024E2': 'Samsung Electronics',
    '1C5216': 'Samsung Electronics',
    '5492BE': 'Samsung Electronics',

    // Sony
    '0009DD': 'Sony Corporation',
    '0013A9': 'Sony Corporation',
    '001DBA': 'Sony Corporation',
    'F4428F': 'Sony Audio',

    // Espressif / Covert IoT / ESP32
    'AC3743': 'Espressif (ESP32/ESP8266)',
    '240AC4': 'Espressif (ESP32/ESP8266)',
    '30AEA4': 'Espressif (ESP32/ESP8266)',
    '70039F': 'Espressif (ESP32/ESP8266)',
    'CC50E3': 'Espressif (ESP32/ESP8266)',
    'E89F6D': 'Espressif (ESP32/ESP8266)',
    '840D8E': 'Espressif (ESP32/ESP8266)',
    '4022D8': 'Espressif (ESP32/ESP8266)',

    // Xiaomi / Redmi / Huami
    '1882A3': 'Xiaomi / Redmi',
    '04CF8C': 'Xiaomi / Redmi',
    '14F65A': 'Xiaomi / Redmi',
    '640980': 'Xiaomi / Redmi',
    'F40E22': 'Huami Amazfit',

    // Realtek / Audio
    '2C0B40': 'Realtek BLE',
    '0025D3': 'Realtek BLE',
    'B4994C': 'Realtek BLE',
  };

  /// Known Standard Service UUIDs
  static const Map<String, String> _serviceUuidMap = {
    '180A': 'Device Information',
    '180F': 'Battery Service',
    '180D': 'Heart Rate Monitor',
    '1802': 'Immediate Alert',
    'FE9F': 'Google Fast Pair',
    'FD6F': 'Exposure Notification',
    '1812': 'HID Human Interface',
  };

  /// Resolves Manufacturer Name using MAC Address OUI & BLE Manufacturer Data
  static String resolveManufacturer(
    String macAddress,
    Map<int, List<int>> manufacturerData,
  ) {
    // 1. Check BLE Manufacturer Data Company ID
    if (manufacturerData.isNotEmpty) {
      for (final companyId in manufacturerData.keys) {
        final vendor = _bleCompanyMap[companyId];
        if (vendor != null) return vendor;
      }
    }

    // 2. Check MAC Address OUI Prefix (First 6 HEX chars)
    final cleanMac =
        macAddress.replaceAll(':', '').replaceAll('-', '').toUpperCase();
    if (cleanMac.length >= 6) {
      final oui = cleanMac.substring(0, 6);
      final vendor = _macOuiMap[oui];
      if (vendor != null) return vendor;
    }

    return 'Generic BLE Hardware';
  }

  /// Categorizes device into specific Exam Security Category
  static String resolveDeviceType(
    String name,
    String manufacturer,
    List<String> serviceUuids,
  ) {
    final lowerName = name.toLowerCase();
    final lowerMfg = manufacturer.toLowerCase();

    final hasAudioUuid = serviceUuids.any((u) => u.toUpperCase().contains('180A') || u.toUpperCase().contains('FE9F'));

    // 1. Detect Wi-Fi Hotspot / Mobile Tethering AP Broadcasts
    if (lowerName.contains('hotspot') ||
        lowerName.contains('tether') ||
        lowerName.contains('direct-') ||
        lowerName.contains('androidap') ||
        lowerName.contains('netgear') ||
        lowerName.contains('tp-link') ||
        lowerName.contains('huawei') ||
        lowerName.contains('my wifi') ||
        lowerName.contains('mobile_ap') ||
        lowerName.contains('portable')) {
      return 'Wi-Fi Hotspot / Mobile AP';
    }

    // 2. Detect Smart Earpieces / Earbuds / Headphones
    if (lowerName.contains('ear') ||
        lowerName.contains('bud') ||
        lowerName.contains('tws') ||
        lowerName.contains('headset') ||
        lowerName.contains('airpod') ||
        lowerName.contains('audio') ||
        lowerName.contains('sound') ||
        lowerName.contains('tune') ||
        lowerName.contains('jbl') ||
        lowerName.contains('beats') ||
        lowerName.contains('bose') ||
        lowerMfg.contains('bose') ||
        lowerMfg.contains('sony') ||
        lowerMfg.contains('anker') ||
        lowerMfg.contains('jbl') ||
        lowerMfg.contains('baseus') ||
        hasAudioUuid) {
      return 'Smart Earpiece / Audio';
    }

    // 3. Detect Smartwatch / Fitness Bands
    if (lowerName.contains('watch') ||
        lowerName.contains('band') ||
        lowerName.contains('fit') ||
        lowerName.contains('wear') ||
        lowerMfg.contains('garmin') ||
        lowerMfg.contains('huami') ||
        lowerMfg.contains('amazfit')) {
      return 'Smartwatch / Wearable';
    }

    // 4. Detect Smartphones / Cellular Mobile Devices
    if (lowerName.contains('phone') ||
        lowerName.contains('iphone') ||
        lowerName.contains('galaxy') ||
        lowerName.contains('pixel') ||
        lowerName.contains('redmi') ||
        lowerName.contains('realme') ||
        lowerName.contains('oneplus') ||
        lowerMfg.contains('apple') ||
        lowerMfg.contains('samsung')) {
      return 'Smartphone / Mobile';
    }

    // 5. Detect Covert ESP32 / Microcontrollers / Bluetooth Bugs
    if (lowerMfg.contains('espressif') ||
        lowerName.contains('esp32') ||
        lowerName.contains('esp8266') ||
        lowerName.contains('arduino') ||
        lowerName.contains('hc-05') ||
        lowerMfg.contains('nordic')) {
      return 'Covert Microcontroller / ESP32';
    }

    return 'BLE Broadcast Beacon';
  }

  /// Resolves human readable description of advertised BLE Service UUIDs
  static List<String> resolveServiceNames(List<String> serviceUuids) {
    return serviceUuids.map((uuid) {
      final clean = uuid.replaceAll('-', '').toUpperCase();
      for (final entry in _serviceUuidMap.entries) {
        if (clean.contains(entry.key)) return entry.value;
      }
      return 'Service ($uuid)';
    }).toList();
  }
}
