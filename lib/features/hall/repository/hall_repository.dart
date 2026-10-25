import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/local_link/i_local_link.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';

/// Hall link plumbing: the hub (when hosting), the client (when joined),
/// this phone's address, and the stable ids / keys kept on the phone.
class HallRepository {
  HallRepository(this.hub, this.client, this._address, this._storage);

  /// Fixed so ESP32 nodes find the hub at `<gateway>:47800`.
  static const int defaultPort = 47800;

  static const String _memberIdKey = 'hall_member_id';
  static const String _nodeKeyKey = 'hall_node_key';

  /// No 0/O, 1/I/L: tokens are also read aloud and typed into config.h.
  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  final ILocalLinkHub hub;
  final ILocalLinkClient client;
  final ILocalAddressLookup _address;
  final ILocalStorage _storage;
  final Random _random = Random.secure();

  String _randomCode(int length) => String.fromCharCodes([
    for (var i = 0; i < length; i++)
      _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
  ]);

  /// A fresh join token for one hosted hall.
  String newToken() => _randomCode(8);

  /// This phone's id in every hall (kept, so a rejoin replaces itself).
  String get memberId => _stored(_memberIdKey, () => 'P-${_randomCode(6)}');

  /// Key ESP32 nodes use to join halls hosted by this phone.
  String get nodeKey => _stored(_nodeKeyKey, () => _randomCode(10));

  String _stored(String key, String Function() create) {
    final existing = _storage.read<String>(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final value = create();
    _storage.write(key, value);
    return value;
  }

  /// Replaces the node key; nodes configured with the old one can't join.
  Future<String> regenerateNodeKey() async {
    final value = _randomCode(10);
    await _storage.write(_nodeKeyKey, value);
    return value;
  }

  Future<String?> localIpv4() => _address.localIpv4();
}

final hallRepositoryProvider = Provider<HallRepository>(
  (ref) => HallRepository(
    ref.watch(localLinkHubProvider),
    ref.watch(localLinkClientProvider),
    ref.watch(localAddressLookupProvider),
    ref.watch(localStorageProvider),
  ),
);
