// The rename from ExamGuard to Pahara must not orphan nodes or hall codes
// made before it.

import 'package:exam_guard/core/utils/app_brand.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pahara and pre-rename ExamGuard nodes are both recognised', () {
    expect(AppBrand.isNodeName('Pahara-Node-A1B2C3'), isTrue);
    expect(AppBrand.isNodeName(' pahara-back-row'), isTrue);
    expect(AppBrand.isNodeName('ExamGuard-Node-01'), isTrue);
    expect(AppBrand.isNodeName('ESP32-DevKit'), isFalse);
    expect(AppBrand.isNodeName('Galaxy Buds'), isFalse);
  });

  test('short node names drop the brand', () {
    expect(AppBrand.shortNodeName('Pahara-Node-A1B2C3'), 'A1B2C3');
    expect(AppBrand.shortNodeName('Pahara-Back-row'), 'Back-row');
    expect(AppBrand.shortNodeName('ExamGuard-Front'), 'Front');
    expect(AppBrand.shortNodeName('Other'), 'Other');
  });

  test('new codes use pahara://; old examguard:// codes still join', () {
    const invite = HallInvite(
      host: '192.168.43.1',
      port: 47800,
      token: 'ABCD2345',
      room: '12',
    );
    expect(invite.encode(), startsWith('pahara://join?'));
    final legacy = HallInvite.parse(
      'examguard://join?h=192.168.43.1&p=47800&t=ABCD2345&r=12',
    );
    expect(legacy?.token, 'ABCD2345');
    expect(HallInvite.parse('other://join?h=1&p=1&t=x'), isNull);
  });
}
