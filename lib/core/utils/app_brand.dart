/// The app's public name, and the names its ESP32 sensor nodes advertise.
abstract final class AppBrand {
  static const String name = 'Pahara';
  static const String fullName = 'Pahara – Exam Hall Security';

  /// Advertised-name prefix of Pahara sensor nodes, e.g. "Pahara-Back-row".
  static const String nodePrefix = 'Pahara-';

  /// "Pahara" is the app's name before the rename: nodes flashed with
  /// that firmware are still recognised.
  static const List<String> _nodePrefixes = ['pahara', 'examguard'];

  /// True for a Pahara sensor node's Bluetooth name (case-insensitive).
  static bool isNodeName(String name) {
    final n = name.trim().toLowerCase();
    return _nodePrefixes.any(n.startsWith);
  }

  /// "Pahara-Node-A1B2C3" → "Node-A1B2C3", "Pahara-Back-row" → "Back-row".
  static String shortNodeName(String name) {
    final lower = name.toLowerCase();
    for (final p in _nodePrefixes) {
      if (lower.startsWith('$p-node-')) return name.substring(p.length + 6);
      if (lower.startsWith('$p-')) return name.substring(p.length + 1);
    }
    return name;
  }
}
