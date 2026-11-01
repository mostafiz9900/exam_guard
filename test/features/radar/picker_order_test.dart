// The radar's device picker must not move rows under the user's finger,
// and must list devices in the order of the distance it shows.

import 'package:exam_guard/features/radar/view/widgets/radar_device_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closest first by the distance shown, stable among equals', () {
    final order = pickerOrder(
      previous: const ['far', 'two', 'close', 'twoB'],
      bucketOf: const {'far': 10, 'two': 2, 'close': 0, 'twoB': 2},
      resort: true,
    );
    expect(order, ['close', 'two', 'twoB', 'far']);
  });

  test('between re-sorts rows hold still; new rows join at the end', () {
    final order = pickerOrder(
      previous: const ['a', 'b', 'gone'],
      bucketOf: const {'b': 0, 'a': 9, 'new': 0},
      resort: false,
    );
    expect(order, ['a', 'b', 'new']);
  });

  test('distance steps match the text: <1 m, ≈N m, >10 m', () {
    expect(distanceBucket(-50, null), 0);
    expect(distanceBucket(-100, null), 10);
    final mid = distanceBucket(-70, null);
    expect(mid, inInclusiveRange(1, 9));
    // A strong transmitter at the same RSSI is farther away.
    expect(distanceBucket(-70, 10), greaterThanOrEqualTo(mid));
  });
}
