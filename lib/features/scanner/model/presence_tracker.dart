import 'package:meta/meta.dart';

/// One signal reading kept for the timeline / report evidence.
@immutable
class SignalSample {
  const SignalSample(this.at, this.rssi);

  final DateTime at;
  final int rssi;
}

/// A stretch of time a device was heard without a long silence.
@immutable
class PresenceInterval {
  const PresenceInterval(this.start, this.end);

  final DateTime start;
  final DateTime end;

  Duration get length => end.difference(start);
}

/// What the scanner knows about one device over time.
@immutable
class DeviceHistory {
  const DeviceHistory({
    required this.intervals,
    required this.samples,
    required this.reappearances,
    required this.peakRssi,
  });

  /// Oldest first; the last one is the current / latest presence.
  final List<PresenceInterval> intervals;

  /// Oldest first, about one per [PresenceTracker.sampleEvery].
  final List<SignalSample> samples;

  /// Times it came back after being gone (≥ [PresenceTracker.goneAfter]).
  final List<DateTime> reappearances;
  final int peakRssi;

  DateTime get firstSeen => intervals.first.start;
  DateTime get lastSeen => intervals.last.end;

  /// Total time it was present (silences excluded).
  Duration get timePresent =>
      intervals.fold(Duration.zero, (sum, i) => sum + i.length);
}

/// Per-device presence and signal history for the scanner's timeline.
///
/// A device that goes silent for [goneAfter] (the scanner's own eviction
/// time) and is heard again "reappears". A BLE device that reappears
/// [toggleCount] times within [toggleWindow] is *toggling* — someone may be
/// switching it (or its Bluetooth) on and off to dodge the scan. Classic
/// Bluetooth and Wi-Fi are only scanned every 35–65 s, so they are never
/// judged as toggling.
class PresenceTracker {
  static const Duration sampleEvery = Duration(seconds: 5);
  static const Duration goneAfter = Duration(seconds: 30);
  static const Duration keepFor = Duration(minutes: 30);
  static const Duration toggleWindow = Duration(minutes: 15);
  static const int toggleCount = 3;

  final Map<String, _Entry> _entries = {};

  /// Records a sighting of [id] at [at]. [canToggle]: BLE only.
  void record(String id, int rssi, DateTime at, {bool canToggle = true}) {
    final e = _entries.putIfAbsent(id, () => _Entry(canToggle));
    e.canToggle = canToggle;
    final last = e.intervals.isEmpty ? null : e.intervals.last;
    if (last == null) {
      e.intervals.add(_Interval(at, at));
    } else if (at.difference(last.end) >= goneAfter) {
      e.intervals.add(_Interval(at, at));
      e.reappearances.add(at);
    } else if (at.isAfter(last.end)) {
      last.end = at;
    }
    if (e.samples.isEmpty || at.difference(e.samples.last.at) >= sampleEvery) {
      e.samples.add(SignalSample(at, rssi));
    }
    if (e.peakRssi == null || rssi > e.peakRssi!) e.peakRssi = rssi;
    _trim(e, at);
  }

  /// [newId] is [oldId] after a random address change: one history.
  void alias(String oldId, String newId) {
    final old = _entries.remove(oldId);
    if (old == null) return;
    final current = _entries[newId];
    if (current == null) {
      _entries[newId] = old;
      return;
    }
    // Both exist: keep the older history, then the newer readings.
    old.intervals.addAll(current.intervals);
    old.samples.addAll(current.samples);
    old.reappearances.addAll(current.reappearances);
    final peaks = [old.peakRssi, current.peakRssi].whereType<int>();
    old.peakRssi = peaks.isEmpty ? null : peaks.reduce((a, b) => a > b ? a : b);
    _entries[newId] = old;
  }

  DeviceHistory? historyOf(String id) {
    final e = _entries[id];
    if (e == null || e.intervals.isEmpty) return null;
    return DeviceHistory(
      intervals: List.unmodifiable([
        for (final i in e.intervals) PresenceInterval(i.start, i.end),
      ]),
      samples: List.unmodifiable(e.samples),
      reappearances: List.unmodifiable(e.reappearances),
      peakRssi: e.peakRssi ?? 0,
    );
  }

  /// BLE devices that reappeared [toggleCount] times within [toggleWindow].
  Set<String> togglingIds(DateTime now) => {
    for (final entry in _entries.entries)
      if (entry.value.canToggle &&
          entry.value.reappearances
                  .where((t) => now.difference(t) <= toggleWindow)
                  .length >=
              toggleCount)
        entry.key,
  };

  /// Drops histories not heard for [keepFor].
  void prune(DateTime now) => _entries.removeWhere(
    (_, e) => now.difference(e.intervals.last.end) > keepFor,
  );

  void clear() => _entries.clear();

  void _trim(_Entry e, DateTime now) {
    final cutoff = now.subtract(keepFor);
    e.samples.removeWhere((s) => s.at.isBefore(cutoff));
    e.reappearances.removeWhere((t) => t.isBefore(cutoff));
    while (e.intervals.length > 1 && e.intervals.first.end.isBefore(cutoff)) {
      e.intervals.removeAt(0);
    }
  }
}

class _Interval {
  _Interval(this.start, this.end);

  final DateTime start;
  DateTime end;
}

class _Entry {
  _Entry(this.canToggle);

  bool canToggle;
  final List<_Interval> intervals = [];
  final List<SignalSample> samples = [];
  final List<DateTime> reappearances = [];
  int? peakRssi;
}
