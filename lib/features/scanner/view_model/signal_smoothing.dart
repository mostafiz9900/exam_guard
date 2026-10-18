/// Display smoothing for the scanner list. BLE RSSI jumps ±3–6 dB per
/// packet; showing raw values made numbers, colours and the proximity label
/// flicker several times a second.
library;

/// Per-device exponential moving average of RSSI.
class RssiSmoother {
  RssiSmoother({this.alpha = defaultAlpha});

  /// Weight of each new sample.
  static const double defaultAlpha = 0.3;

  final double alpha;
  final Map<String, double> _values = {};

  /// Adds [rssi] for [id] and returns the smoothed value. The first sample
  /// is taken as is.
  double add(String id, int rssi) {
    final previous = _values[id];
    final next = previous == null
        ? rssi.toDouble()
        : previous + alpha * (rssi - previous);
    _values[id] = next;
    return next;
  }

  /// Smoothed value of [id], or null when nothing was heard.
  double? valueOf(String id) => _values[id];

  /// Starts [newId] from [oldId]'s value (a rotated random address).
  void inherit(String oldId, String newId) {
    final v = _values.remove(oldId);
    if (v != null) _values.putIfAbsent(newId, () => v);
  }

  void remove(String id) => _values.remove(id);

  void retainOnly(Set<String> ids) =>
      _values.removeWhere((id, _) => !ids.contains(id));

  void clear() => _values.clear();
}

/// How close a device seems, from its (smoothed) signal. Same thresholds as
/// the dashboard: > -65 dBm very close, > -75 near, > -88 in range.
enum ProximityBand {
  veryClose,
  near,
  inRange,
  distant;

  /// A band changes only once the signal is this far past the boundary,
  /// so a value hovering at -65 dBm doesn't flip the label.
  static const int hysteresisDb = 3;

  static ProximityBand fromRssi(num rssi) {
    if (rssi > -65) return veryClose;
    if (rssi > -75) return near;
    if (rssi > -88) return inRange;
    return distant;
  }

  /// The band for [rssi] given the band shown before ([previous]).
  static ProximityBand next(ProximityBand? previous, num rssi) {
    final raw = fromRssi(rssi);
    if (previous == null || raw == previous) return raw;
    // Lower index = stronger.
    if (raw.index < previous.index) {
      final confirmed = fromRssi(rssi - hysteresisDb);
      return confirmed.index < previous.index ? confirmed : previous;
    }
    final confirmed = fromRssi(rssi + hysteresisDb);
    return confirmed.index > previous.index ? confirmed : previous;
  }

  /// Signal bars (1–4).
  int get bars => 4 - index;

  /// Translation key of the label.
  String get labelKey => switch (this) {
    veryClose => 'scan_proximity_very_close',
    near => 'scan_proximity_near',
    inRange => 'scan_proximity_in_range',
    distant => 'scan_proximity_distant',
  };
}
