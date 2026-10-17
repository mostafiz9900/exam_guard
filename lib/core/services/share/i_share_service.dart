import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/share/share_service_impl.dart';

enum ShareOutcome { shared, dismissed, unavailable }

/// Thrown when the share sheet could not be opened. The cause is logged.
class ShareFailedException implements Exception {
  const ShareFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'ShareFailedException: $cause';
}

/// System share sheet. Features use this instead of `share_plus`.
///
/// [origin] is the global rect of the widget that triggered the share; iPad
/// anchors its share popover there.
abstract interface class IShareService {
  /// [fileName] is sanitized with [safeFileName] before use.
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
    Rect? origin,
  });

  Future<ShareOutcome> shareText(String text, {String? subject, Rect? origin});
}

/// Makes [fileName] safe to use as a file path segment: every character
/// outside `[A-Za-z0-9_-]` in the name part becomes `_` (e.g. room "12/B").
/// The extension is kept when it is alphanumeric. Falls back to `file`.
String safeFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot > 0 ? fileName.substring(dot + 1) : '';
  final keepExt = ext.isNotEmpty && RegExp(r'^[A-Za-z0-9]+$').hasMatch(ext);
  final name = keepExt ? fileName.substring(0, dot) : fileName;
  var safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  if (safe.replaceAll('_', '').isEmpty) safe = 'file';
  return keepExt ? '$safe.$ext' : safe;
}

final shareServiceProvider = Provider<IShareService>(
  (ref) => ShareServiceImpl(ref.watch(appLoggerProvider)),
);
