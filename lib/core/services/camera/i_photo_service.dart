import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/camera/photo_service_impl.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

/// Taking a photo failed (camera unavailable, storage error).
class PhotoException implements Exception {
  const PhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Evidence photos. Features use this instead of camera/file packages.
abstract interface class IPhotoService {
  /// Opens the camera; returns the saved file's absolute path, or null when
  /// the user cancelled. Throws [PhotoException] on failure.
  Future<String?> takePhoto();

  /// Deletes a photo saved by [takePhoto]; missing files are ignored.
  Future<void> delete(String path);

  /// Whether the file still exists (photos can be cleared by the OS/user).
  Future<bool> exists(String path);
}

final photoServiceProvider = Provider<IPhotoService>(
  (ref) => PhotoServiceImpl(ref.read(appLoggerProvider)),
);
