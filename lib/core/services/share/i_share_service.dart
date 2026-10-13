import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'share_service_impl.dart';

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
}

final shareServiceProvider = Provider<IShareService>(
  (ref) => ShareServiceImpl(),
);
