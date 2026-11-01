import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/sensors/i_heading_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/radar/repository/radar_repository.dart';
import 'package:exam_guard/features/session/model/room_profile.dart';

/// Compass heading, the target's signal, and the "front of the hall"
/// heading kept per room.
class DirectionRepository {
  DirectionRepository(this._heading, this._storage, this._radar);

  final IHeadingService _heading;
  final ILocalStorage _storage;
  final RadarRepository _radar;

  static String _frontKey(String room) =>
      'hall_front_heading_${RoomProfile.keyOf(room)}';

  /// Errors with [HeadingUnavailableException] on phones without a compass.
  Stream<HeadingReading> headings() => _heading.headings();

  /// Every BLE packet the running radar scan receives.
  Stream<RadarSignal> signals() => _radar.watchAll();

  double? frontHeading(String room) {
    final v = _storage.read<num>(_frontKey(room));
    return v?.toDouble();
  }

  /// Throws [StorageException].
  Future<void> saveFront(String room, double heading) =>
      _storage.write(_frontKey(room), heading);
}

final directionRepositoryProvider = Provider<DirectionRepository>(
  (ref) => DirectionRepository(
    ref.watch(headingServiceProvider),
    ref.watch(localStorageProvider),
    ref.watch(radarRepositoryProvider),
  ),
);
