import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'package:exam_guard/core/services/share/i_share_service.dart';

class ShareServiceImpl implements IShareService {
  @override
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        fileNameOverrides: [fileName],
        subject: subject,
        text: text,
      ),
    );
    return _map(result.status);
  }

  @override
  Future<ShareOutcome> shareText(String text, {String? subject}) async {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
    return _map(result.status);
  }

  ShareOutcome _map(ShareResultStatus status) => switch (status) {
    ShareResultStatus.success => ShareOutcome.shared,
    ShareResultStatus.dismissed => ShareOutcome.dismissed,
    ShareResultStatus.unavailable => ShareOutcome.unavailable,
  };
}
