import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/share/share_service_impl.dart';

enum ShareOutcome { shared, dismissed, unavailable }

/// System share sheet. Features use this instead of `share_plus`.
abstract interface class IShareService {
  Future<ShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
  });

  Future<ShareOutcome> shareText(String text, {String? subject});
}

final shareServiceProvider = Provider<IShareService>(
  (ref) => ShareServiceImpl(),
);
