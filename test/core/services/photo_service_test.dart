import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exam_guard/core/services/camera/i_photo_service.dart';
import 'package:exam_guard/core/services/camera/photo_service_impl.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await Directory.systemTemp.createTemp('photo_test'));
  tearDown(() async => tmp.delete(recursive: true));

  PhotoServiceImpl build(CameraCapture capture) => PhotoServiceImpl(
    AppLogger(),
    capture: capture,
    documentsDirectory: () async => tmp,
    clock: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );

  test('cancel returns null', () async {
    final service = build(() async => null);
    expect(await service.takePhoto(), isNull);
    expect(Directory('${tmp.path}/evidence').existsSync(), isFalse);
  });

  test('copies the picture into documents/evidence', () async {
    final temp = File('${tmp.path}/picker_tmp.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    final service = build(() async => temp.path);

    final path = await service.takePhoto();
    expect(path, '${tmp.path}/evidence/1700000000000.jpg');
    expect(File(path!).readAsBytesSync(), [1, 2, 3]);
    expect(temp.existsSync(), isFalse);
    expect(await service.exists(path), isTrue);

    await service.delete(path);
    expect(await service.exists(path), isFalse);
    // Missing files are ignored.
    await service.delete(path);
  });

  test('camera errors become PhotoException with a safe message', () async {
    final service = build(
      () async => throw PlatformException(code: 'camera_access_denied'),
    );
    expect(
      service.takePhoto(),
      throwsA(
        isA<PhotoException>().having(
          (e) => e.message,
          'message',
          contains('Settings'),
        ),
      ),
    );
  });

  test('a missing temp file becomes PhotoException', () async {
    final service = build(() async => '${tmp.path}/nope.jpg');
    expect(service.takePhoto(), throwsA(isA<PhotoException>()));
  });
}
