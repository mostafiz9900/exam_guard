import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/features/session/domain/session_model.dart';
import 'package:exam_guard/core/services/local_storage/i_local_storage.dart';

/// Provider that must be overridden by the application bootstrap with a
/// real [HiveStorageImpl] instance. The default throws to make misconfiguration
/// obvious during development.
final localStorageProvider = Provider<ILocalStorage>(
  (ref) => throw UnimplementedError(
    'Provide a HiveStorageImpl in ProviderScope overrides',
  ),
);

class HiveStorageImpl implements ILocalStorage {
  static const _boxName = 'exam_guard_storage';
  final Box _box;

  HiveStorageImpl._(this._box);

  /// Factory that ensures Hive is initialized and the storage box opened.
  static Future<HiveStorageImpl> create() async {
    await Hive.initFlutter();
    final box = await Hive.openBox(_boxName);
    return HiveStorageImpl._(box);
  }

  /// Convenience initialization which only prepares Hive for use. This can
  /// be called during app bootstrap if higher-level code needs to control
  /// when the storage box is opened.
  static Future<void> initHive() async {
    await Hive.initFlutter();
  }

  String _sessionKey(String id) => 'session_$id';

  @override
  Future<void> saveSession(SessionModel session) async {
    try {
      await _box.put(_sessionKey(session.id), session.toJson());
      await _box.put('current_session_id', session.id);
    } catch (e) {
      if (kDebugMode) rethrow;
      throw Exception('Failed to save session: $e');
    }
  }

  @override
  Future<SessionModel?> getCurrentSession() async {
    final id = _box.get('current_session_id') as String?;
    if (id == null) return null;
    final raw = _box.get(_sessionKey(id));
    if (raw == null) return null;
    return SessionModel.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<void> endSession(SessionModel session) async {
    final updated = session.copyWith(
      endTime: session.endTime ?? DateTime.now(),
    );
    await _box.put(_sessionKey(updated.id), updated.toJson());
    // Clear current session marker
    await _box.delete('current_session_id');
  }

  @override
  Future<List<SessionModel>> getAllSessions() async {
    final sessions = <SessionModel>[];
    for (final key in _box.keys) {
      if (key is String && key.startsWith('session_')) {
        final raw = _box.get(key);
        if (raw is Map) {
          sessions.add(SessionModel.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return sessions;
  }

  @override
  Future<void> dispose() async {
    await _box.close();
  }
}
