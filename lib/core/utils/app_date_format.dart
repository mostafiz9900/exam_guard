import 'package:easy_localization/easy_localization.dart' as easy;

/// Date/time formatting used across the app. Wraps `intl`'s DateFormat.
class AppDateFormat {
  AppDateFormat._();

  /// 03:45:12 PM
  static String clock(DateTime d) => easy.DateFormat('hh:mm:ss a').format(d);

  /// Oct 13, 03:45 PM
  static String shortDateTime(DateTime d) =>
      easy.DateFormat('MMM d, hh:mm a').format(d);

  /// 2026-10-13 03:45:12 PM
  static String fullDateTime(DateTime d) =>
      easy.DateFormat('yyyy-MM-dd hh:mm:ss a').format(d);

  /// 2026-10-13 15:45:12 (for CSV / machine-readable output)
  static String sortableDateTime(DateTime d) =>
      easy.DateFormat('yyyy-MM-dd HH:mm:ss').format(d);

  /// 2026-10-13
  static String date(DateTime d) => easy.DateFormat('yyyy-MM-dd').format(d);
}
