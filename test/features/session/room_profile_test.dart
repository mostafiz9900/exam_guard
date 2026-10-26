// Room profile storage format and room-number matching.

import 'package:exam_guard/features/session/model/activity_sample.dart';
import 'package:exam_guard/features/session/model/room_profile.dart';
import 'package:exam_guard/features/session/model/session_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the same room however it is typed', () {
    expect(RoomProfile.keyOf('302-B'), RoomProfile.keyOf(' 302 - b '));
    expect(RoomProfile.keyOf('302-B'), RoomProfile.keyOf('302B'));
    expect(RoomProfile.keyOf('Hall 2/A'), RoomProfile.keyOf('hall2a'));
    expect(RoomProfile.keyOf('302-B'), isNot(RoomProfile.keyOf('302-C')));
  });

  test('profile round-trips; bad items are skipped', () {
    final p = RoomProfile(
      room: '302-B',
      savedAt: DateTime(2026, 10, 26, 9),
      items: const [
        RoomProfileItem(
          id: 'wifi:11:22',
          name: 'School-WiFi',
          type: 'Wi-Fi Access Point',
          transport: 'wifi',
        ),
      ],
    );
    final json = p.toJson();
    (json['items'] as List).add({'name': 'no id'});
    final back = RoomProfile.fromJson(json)!;
    expect(back.room, '302-B');
    expect(back.ids, {'wifi:11:22'});
    expect(back.savedAt, p.savedAt);
  });

  test('session keeps profile ids and activity through storage', () {
    final s = SessionModel(
      id: '1',
      instituteName: 'S',
      teacherName: 'T',
      roomNumber: '302-B',
      startTime: DateTime(2026, 10, 26, 9),
      profileDeviceIds: const {'a'},
      activity: [
        ActivitySample(
          at: DateTime(2026, 10, 26, 9, 1),
          devices: 5,
          untrusted: 2,
          alerts: 1,
        ),
      ],
    );
    final back = SessionModel.fromJson(s.toJson());
    expect(back.profileDeviceIds, {'a'});
    expect(back.activity.single.untrusted, 2);
    // Sessions saved before these fields existed still load.
    final old = s.toJson()
      ..remove('profileDeviceIds')
      ..remove('activity');
    expect(SessionModel.fromJson(old).activity, isEmpty);
  });
}
