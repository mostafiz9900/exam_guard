import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';

class ShareServiceImpl implements IShareService {
  ShareServiceImpl(this._logger);

  final AppLogger _logger;

  @override
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
    Rect? origin,
  }) {
    final name = safeFileName(fileName);
    return _share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: name)],
        fileNameOverrides: [name],
        subject: subject,
        text: text,
        sharePositionOrigin: origin,
      ),
    );
  }

  @override
  Future<ShareOutcome> shareText(
    String text, {
    String? subject,
    Rect? origin,
  }) => _share(
    ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
  );

  Future<ShareOutcome> _share(ShareParams params) async {
    try {
      final result = await SharePlus.instance.share(params);
      return _map(result.status);
    } catch (e, st) {
      _logger.error('Opening the share sheet failed', e, st);
      throw ShareFailedException(e);
    }
  }

  ShareOutcome _map(ShareResultStatus status) => switch (status) {
    ShareResultStatus.success => ShareOutcome.shared,
    ShareResultStatus.dismissed => ShareOutcome.dismissed,
    ShareResultStatus.unavailable => ShareOutcome.unavailable,
  };
}
