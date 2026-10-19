import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:exam_guard/core/services/camera/i_photo_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

/// Opens the system camera; returns the temporary file path, or null when
/// the user cancelled.
typedef CameraCapture = Future<String?> Function();

/// Evidence photos via `image_picker` (system camera app, so no CAMERA
/// permission is declared on Android) stored under
/// `<app documents>/evidence/<timestamp>.jpg`.
class PhotoServiceImpl implements IPhotoService {
  PhotoServiceImpl(
    this._logger, {
    CameraCapture? capture,
    Future<Directory> Function()? documentsDirectory,
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock,
       _capture = capture ?? _pickFromCamera,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final AppLogger _logger;
  final CameraCapture _capture;
  final Future<Directory> Function() _documentsDirectory;
  final DateTime Function() _clock;

  static Future<String?> _pickFromCamera() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1600,
    );
    return file?.path;
  }

  @override
  Future<String?> takePhoto() async {
    final String? tempPath;
    try {
      tempPath = await _capture();
    } on PlatformException catch (e, st) {
      _logger.warning('Camera failed: ${e.code}', e, st);
      throw PhotoException(_cameraMessage(e.code));
    } catch (e, st) {
      _logger.error('Camera failed', e, st);
      throw const PhotoException('Could not open the camera.');
    }
    if (tempPath == null) return null;

    try {
      final docs = await _documentsDirectory();
      final dir = Directory('${docs.path}/evidence');
      await dir.create(recursive: true);
      final target = '${dir.path}/${_clock().millisecondsSinceEpoch}.jpg';
      final source = File(tempPath);
      await source.copy(target);
      try {
        await source.delete();
      } catch (e, st) {
        _logger.warning('Could not delete camera temp file', e, st);
      }
      _logger.info('Evidence photo saved: $target');
      return target;
    } catch (e, st) {
      _logger.error('Saving evidence photo failed', e, st);
      throw const PhotoException('Could not save the photo.');
    }
  }

  static String _cameraMessage(String code) => switch (code) {
    'camera_access_denied' || 'camera_access_restricted' =>
      'Camera access is denied. Allow it in Settings.',
    'no_available_camera' => 'No camera is available on this device.',
    _ => 'Could not open the camera.',
  };

  @override
  Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e, st) {
      _logger.warning('Deleting photo failed: $path', e, st);
    }
  }

  @override
  Future<bool> exists(String path) async {
    try {
      return await File(path).exists();
    } catch (e, st) {
      _logger.warning('Checking photo failed: $path', e, st);
      return false;
    }
  }
}
