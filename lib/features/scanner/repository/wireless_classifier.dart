import 'package:exam_guard/features/scanner/repository/bluetooth_device_inspector.dart';

/// Pure classification rules for classic Bluetooth and Wi-Fi results.
///
/// Category strings match the BLE ones in [BluetoothDeviceInspector] so the
/// scanner's filters (`contains('Audio')`, `contains('Hotspot')`, ...) work
/// for every transport.
class WirelessClassifier {
  WirelessClassifier._();

  static const String audioType = 'Smart Earpiece / Audio';
  static const String phoneType = 'Smartphone / Mobile';
  static const String wearableType = 'Smartwatch / Wearable';
  static const String computerType = 'Computer / Laptop';

  /// Classic device whose class and name say nothing more specific.
  static const String classicOtherType = 'Bluetooth Device';
  static const String hotspotType = 'Wi-Fi Hotspot / Mobile AP';

  /// Fixed infrastructure (school/office router). Listed, not suspicious.
  static const String accessPointType = 'Wi-Fi Access Point';

  // ── Classic Bluetooth ────────────────────────────────────────────────

  static const int _majorMask = 0x1F00;

  /// Major + minor bits, as Android's `BluetoothClass.getDeviceClass()`.
  static const int _deviceMask = 0x1FFC;

  static const int majorComputer = 0x0100;
  static const int majorPhone = 0x0200;
  static const int majorAudioVideo = 0x0400;
  static const int majorWearable = 0x0700;

  /// Audio/video minor classes of in-ear / on-head audio: wearable headset,
  /// hands-free and headphones.
  static const Set<int> _earpieceClasses = {0x0404, 0x0408, 0x0418};

  static int? _major(int? majorDeviceClass, int? deviceClass) {
    if (majorDeviceClass != null) return majorDeviceClass & _majorMask;
    if (deviceClass != null) return deviceClass & _majorMask;
    return null;
  }

  /// True for a headset / hands-free / headphones device class — the
  /// profile of classic "spy" earpieces.
  static bool isSpyEarpieceClass(int? deviceClass) =>
      deviceClass != null &&
      _earpieceClasses.contains(deviceClass & _deviceMask);

  /// Category of a classic Bluetooth device: from its device class first,
  /// otherwise from its name and vendor.
  static String classicDeviceType({
    required String name,
    required String manufacturer,
    int? majorDeviceClass,
    int? deviceClass,
  }) {
    switch (_major(majorDeviceClass, deviceClass)) {
      case majorAudioVideo:
        return audioType;
      case majorPhone:
        return phoneType;
      case majorWearable:
        return wearableType;
      case majorComputer:
        return computerType;
    }
    final byName = BluetoothDeviceInspector.resolveDeviceType(
      name,
      manufacturer,
      const [],
    );
    return byName == 'BLE Broadcast Beacon' ? classicOtherType : byName;
  }

  // ── Wi-Fi ────────────────────────────────────────────────────────────

  /// SSID prefixes phones use for their hotspot by default.
  static const List<String> _hotspotPrefixes = [
    'androidap',
    'android_',
    'galaxy',
    'redmi',
    'poco',
    'oppo',
    'vivo',
    'realme',
    'infinix',
    'tecno',
    'itel',
    'xiaomi',
    'huawei',
    'honor',
    'nokia',
    'pixel',
    'oneplus',
    'motorola',
    'moto ',
    'direct-',
  ];

  static const List<String> _hotspotWords = [
    'iphone',
    'ipad',
    'hotspot',
    'tether',
    'mobile',
    'mifi',
    'jiofi',
  ];

  /// Wi-Fi Direct names of fixed equipment (printers, TVs).
  static const List<String> _directEquipment = [
    'printer',
    '-hp',
    'hp ',
    'smart tank',
    'pixma',
    'mfc-',
    'laserjet',
    'deskjet',
    'officejet',
    'envy',
    'epson',
    'canon',
    'brother',
    'xerox',
    'ricoh',
    'kyocera',
    ' tv',
    'bravia',
    'roku',
  ];

  /// SSIDs of fixed networks (routers, campus Wi-Fi). Only used to keep a
  /// locally administered BSSID from counting as a hotspot.
  static const List<String> _infrastructureWords = [
    'eduroam',
    'guest',
    'staff',
    'office',
    'admin',
    'school',
    'college',
    'university',
    'campus',
    'library',
    'tp-link',
    'tplink',
    'tenda',
    'netgear',
    'linksys',
    'd-link',
    'dlink',
    'asus',
    'mercusys',
    'totolink',
    'mikrotik',
    'ubnt',
    'unifi',
    'cisco',
    'aruba',
    'ruckus',
    'meraki',
    'xfinity',
    'starlink',
    'deco',
    'eero',
    'orbi',
  ];

  static String _normalize(String ssid) =>
      ssid.trim().toLowerCase().replaceAll('’', "'");

  /// True when [ssid] looks like a phone's (or pocket router's) hotspot,
  /// e.g. "AndroidAP_1234", "Rahim's iPhone", "Galaxy A54", "DIRECT-xy-…".
  static bool isPhoneHotspotSsid(String ssid) {
    final s = _normalize(ssid);
    if (s.isEmpty) return false;
    if (s.startsWith('direct-')) {
      return !_directEquipment.any(s.contains);
    }
    return _hotspotPrefixes.any(s.startsWith) || _hotspotWords.any(s.contains);
  }

  /// True when [ssid] names fixed infrastructure.
  static bool isInfrastructureSsid(String ssid) {
    final s = _normalize(ssid);
    return s.isNotEmpty && _infrastructureWords.any(s.contains);
  }

  static List<String>? _octets(String mac) {
    final parts = mac.trim().toUpperCase().split(RegExp('[:-]'));
    if (parts.length != 6 || parts.any((p) => p.length != 2)) return null;
    return parts;
  }

  /// True for a locally administered (randomized) MAC: the second hex digit
  /// is 2, 6, A or E. Phones use these for their hotspot.
  static bool isLocallyAdministeredMac(String mac) {
    final o = _octets(mac);
    if (o == null) return false;
    return const {'2', '6', 'A', 'E'}.contains(o.first[1]);
  }

  /// True when [bssid] is a virtual AP of a router also seen in the same
  /// scan: enterprise and mesh routers derive extra BSSIDs by setting the
  /// local bit on their own MAC, so the middle octets stay the same.
  static bool hasUniversalSibling(String bssid, Iterable<String> scanBssids) {
    final o = _octets(bssid);
    if (o == null) return false;
    final middle = o.sublist(1, 5).join();
    for (final other in scanBssids) {
      if (other.toUpperCase() == bssid.toUpperCase()) continue;
      final p = _octets(other);
      if (p == null || isLocallyAdministeredMac(other)) continue;
      if (p.sublist(1, 5).join() == middle) return true;
    }
    return false;
  }

  /// [hotspotType] when the SSID looks like a phone hotspot, or the BSSID
  /// is randomized and nothing marks it as fixed infrastructure; otherwise
  /// [accessPointType]. [scanBssids] are all BSSIDs from the same scan.
  static String wifiDeviceType(
    String ssid,
    String bssid, {
    Iterable<String> scanBssids = const [],
  }) {
    if (isPhoneHotspotSsid(ssid)) return hotspotType;
    if (isLocallyAdministeredMac(bssid) &&
        !isInfrastructureSsid(ssid) &&
        !hasUniversalSibling(bssid, scanBssids)) {
      return hotspotType;
    }
    return accessPointType;
  }
}
