import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exam_guard/core/services/audio/geiger_buzzer_service.dart';

void main() {
  testWidgets('keeps beeping while distance updates arrive faster than '
      'the beep interval', (tester) async {
    var clicks = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemSound.play') clicks++;
        return null;
      },
    );
    final buzzer = GeigerBuzzerService.instance;

    // 1 m → ~296 ms interval; updates every 100 ms, like BLE advertisements.
    for (var i = 0; i < 20; i++) {
      buzzer.updateTargetDistance(1.0);
      await tester.pump(const Duration(milliseconds: 100));
    }
    buzzer.stopBuzzer();

    expect(clicks, greaterThanOrEqualTo(5));
  });
}
