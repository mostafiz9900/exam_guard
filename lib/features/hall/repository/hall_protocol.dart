import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/scanner/repository/bluetooth_device_inspector.dart';
import 'package:exam_guard/features/scanner/repository/wireless_classifier.dart';
import 'package:exam_guard/features/scanner/model/new_device_alert.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';

/// Hall link protocol v1: JSON objects `{"t": type, "v": 1, ...}` over the
/// local link. Shared with the ESP32 node firmware (firmware/esp32) — keep
/// both in step.
abstract final class HallProtocol {
  static const int version = 1;

  static const String hello = 'hello';
  static const String welcome = 'welcome';
  static const String reject = 'reject';
  static const String sightings = 'sightings';
  static const String alert = 'alert';
  static const String members = 'members';

  /// Reasons in [reject] messages.
  static const String badToken = 'bad_token';
  static const String badVersion = 'bad_version';
  static const String badHello = 'bad_hello';

  /// Sightings per batch: the strongest, enough for any exam hall.
  static const int maxSightings = 60;

  static Map<String, Object?> _msg(String type, Map<String, Object?> body) => {
    't': type,
    'v': version,
    ...body,
  };

  static String? typeOf(Map<String, Object?> json) =>
      json['t'] is String ? json['t']! as String : null;

  // ── hello / welcome / reject ──────────────────────────────────────────

  /// Phones send the invite [token]; nodes send their configured node key
  /// in the same field.
  static Map<String, Object?> encodeHello(HallMember me, String token) =>
      _msg(hello, {'token': token, 'member': me.toJson()});

  static Map<String, Object?> encodeWelcome(
    String room,
    List<HallMember> all,
  ) => _msg(welcome, {
    'room': room,
    'members': [for (final m in all) m.toJson()],
  });

  static Map<String, Object?> encodeReject(String reason) =>
      _msg(reject, {'reason': reason});

  static Map<String, Object?> encodeMembers(List<HallMember> all) =>
      _msg(members, {
        'members': [for (final m in all) m.toJson()],
      });

  static List<HallMember> decodeMembers(Map<String, Object?> json) => [
    for (final m in (json['members'] as List?) ?? const [])
      ?HallMember.fromJson(m),
  ];

  // ── sightings ─────────────────────────────────────────────────────────

  static Map<String, Object?> encodeSightings(
    String from,
    List<ScannedDeviceModel> devices,
  ) => _msg(sightings, {
    'from': from,
    'items': [
      for (final d in devices)
        {
          'id': d.id,
          'name': d.hasName ? d.displayName : '',
          'type': d.deviceType,
          'mfr': d.manufacturer,
          'rssi': d.rssi,
          'tx': d.transport.name,
          'at': d.lastSeen.millisecondsSinceEpoch,
          if (d.txPower != null) 'txp': d.txPower,
        },
    ],
  });

  /// Phones send classified devices. ESP32 nodes send raw clues instead —
  /// `mfid` (company id), `mfb` (first manufacturer byte), `svc` (service
  /// UUIDs) for BLE, the SSID/BSSID for Wi-Fi — and are classified here with
  /// the phones' own rules, so a node's category means the same thing.
  static List<ScannedDeviceModel> decodeSightings(Map<String, Object?> json) {
    final items = (json['items'] as List?) ?? const [];
    final bssids = [
      for (final i in items)
        if (i is Map && i['tx'] == 'wifi' && i['id'] is String)
          (i['id']! as String).replaceFirst(
            ScannedDeviceModel.wifiIdPrefix,
            '',
          ),
    ];
    final out = <ScannedDeviceModel>[];
    for (final item in items) {
      final d = _device(item);
      if (d == null) continue;
      out.add(
        item is Map && item['type'] == null ? _classify(d, item, bssids) : d,
      );
    }
    return out;
  }

  static ScannedDeviceModel _classify(
    ScannedDeviceModel d,
    Map<Object?, Object?> raw,
    List<String> bssids,
  ) {
    if (d.transport == DeviceTransport.wifi) {
      final bssid = d.id.replaceFirst(ScannedDeviceModel.wifiIdPrefix, '');
      return d.copyWith(
        manufacturer: ScannedDeviceModel.wifiManufacturer,
        deviceType: WirelessClassifier.wifiDeviceType(
          d.name,
          bssid,
          scanBssids: bssids,
        ),
      );
    }
    final mfid = raw['mfid'];
    final mfb = raw['mfb'];
    final data = <int, List<int>>{
      if (mfid is num) mfid.toInt(): [if (mfb is num) mfb.toInt()],
    };
    final services = [
      for (final u in (raw['svc'] as List?) ?? const [])
        if (u is String) u.toUpperCase(),
    ];
    final manufacturer = BluetoothDeviceInspector.resolveManufacturer(
      d.id,
      data,
    );
    return d.copyWith(
      manufacturer: manufacturer,
      serviceUuids: services,
      deviceType: BluetoothDeviceInspector.resolveDeviceType(
        d.name,
        manufacturer,
        services,
        data,
      ),
    );
  }

  static ScannedDeviceModel? _device(Object? item) {
    if (item is! Map) return null;
    final id = item['id'];
    final rssi = item['rssi'];
    if (id is! String || id.isEmpty || rssi is! num) return null;
    final at = item['at'];
    final seen = at is num
        ? DateTime.fromMillisecondsSinceEpoch(at.toInt())
        : DateTime.now();
    final txp = item['txp'];
    return ScannedDeviceModel(
      id: id,
      name: item['name'] is String ? item['name']! as String : '',
      manufacturer: item['mfr'] is String && (item['mfr']! as String).isNotEmpty
          ? item['mfr']! as String
          : 'Generic BLE Hardware',
      deviceType: item['type'] is String && (item['type']! as String).isNotEmpty
          ? item['type']! as String
          : 'BLE Broadcast Beacon',
      rssi: rssi.toInt(),
      txPower: txp is num ? txp.toInt() : null,
      isConnectable: false,
      lastSeen: seen,
      firstSeen: seen,
      transport: _transport(item['tx']),
    );
  }

  static DeviceTransport _transport(Object? value) => switch (value) {
    'classic' => DeviceTransport.classic,
    'wifi' => DeviceTransport.wifi,
    _ => DeviceTransport.ble,
  };

  // ── alerts ────────────────────────────────────────────────────────────

  static Map<String, Object?> encodeAlert(String from, NewDeviceAlert a) =>
      _msg(alert, {
        'from': from,
        'alert': {
          'id': a.deviceId,
          'name': a.displayName,
          'type': a.deviceType,
          'tx': a.transport.name,
          'rssi': a.rssi,
          'at': a.detectedAt.millisecondsSinceEpoch,
        },
      });

  static NewDeviceAlert? decodeAlert(Map<String, Object?> json) {
    final a = json['alert'];
    if (a is! Map) return null;
    final id = a['id'];
    final rssi = a['rssi'];
    final at = a['at'];
    if (id is! String || id.isEmpty || rssi is! num || at is! num) return null;
    return NewDeviceAlert(
      deviceId: id,
      displayName: a['name'] is String ? a['name']! as String : id,
      deviceType: a['type'] is String ? a['type']! as String : '',
      transport: _transport(a['tx']),
      rssi: rssi.toInt(),
      detectedAt: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }

  static String? fromOf(Map<String, Object?> json) =>
      json['from'] is String ? json['from']! as String : null;
}
