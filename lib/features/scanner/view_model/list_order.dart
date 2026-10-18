/// Order of the scanner list. Re-sorting on every advertisement made cards
/// jump under the invigilator's finger, so neither mode moves a card on a
/// small signal change.
enum ScanSortMode {
  /// Order of first appearance; new devices are added at the bottom and
  /// existing cards never move.
  stable,

  /// Strongest (smoothed) signal first, trusted devices last. Re-sorted at
  /// most every [NearestOrder.resortEvery], and two cards swap only when
  /// their signals differ by more than [NearestOrder.swapMarginDb].
  nearest;

  String get labelKey => switch (this) {
    ScanSortMode.stable => 'scan_sort_stable',
    ScanSortMode.nearest => 'scan_sort_nearest',
  };
}

/// One list entry to order: its key, smoothed signal and trust.
typedef NearestEntry = ({String key, double rssi, bool trusted});

/// "Nearest first" ordering with a time throttle and hysteresis.
///
/// Between re-sorts the previous order is kept: entries that disappeared
/// are dropped and new ones are appended at the end. A re-sort starts from
/// the previous order and only swaps neighbours that are clearly out of
/// place (> [swapMarginDb]), so signals drifting by a few dB never reorder
/// the list.
class NearestOrder {
  static const Duration resortEvery = Duration(seconds: 3);
  static const double swapMarginDb = 4;

  List<String> _order = const [];
  DateTime? _sortedAt;

  /// Forgets the order; the next [order] call sorts fully.
  void reset() {
    _order = const [];
    _sortedAt = null;
  }

  /// Keys of [entries] in display order at [now].
  List<String> order(List<NearestEntry> entries, DateTime now) {
    final byKey = {for (final e in entries) e.key: e};
    final kept = [
      for (final k in _order)
        if (byKey.containsKey(k)) k,
    ];
    final keptSet = kept.toSet();
    final added = [
      for (final e in entries)
        if (!keptSet.contains(e.key)) e.key,
    ];

    final sortedAt = _sortedAt;
    final firstSort = sortedAt == null;
    final due = firstSort || now.difference(sortedAt) >= resortEvery;
    if (!due) {
      return _order = [...kept, ...added];
    }

    final list = [...kept, ...added];
    final margin = firstSort ? 0.0 : swapMarginDb;
    bool outOfPlace(NearestEntry a, NearestEntry b) {
      if (a.trusted != b.trusted) return a.trusted;
      return b.rssi - a.rssi > margin;
    }

    // Bubble passes keep the previous order wherever it is good enough.
    for (var pass = 0; pass < list.length; pass++) {
      var swapped = false;
      for (var i = 0; i + 1 < list.length; i++) {
        if (outOfPlace(byKey[list[i]]!, byKey[list[i + 1]]!)) {
          final t = list[i];
          list[i] = list[i + 1];
          list[i + 1] = t;
          swapped = true;
        }
      }
      if (!swapped) break;
    }
    _sortedAt = now;
    return _order = list;
  }
}
