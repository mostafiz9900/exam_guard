import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/sensors/i_heading_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/radar/model/direction_finder.dart';
import 'package:exam_guard/features/radar/repository/direction_repository.dart';
import 'package:exam_guard/features/radar/repository/radar_repository.dart';
import 'package:exam_guard/features/radar/view_model/finder_aliases.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

enum DirectionPhase {
  /// Instructions; waiting for Start.
  ready,

  /// The invigilator is turning round; samples are collected.
  turning,

  /// Finished: [DirectionState.result] (null = not a full turn).
  done,
}

@immutable
class DirectionState {
  const DirectionState({
    this.phase = DirectionPhase.ready,
    this.heading,
    this.needsCalibration = false,
    this.headingUnavailable = false,
    this.coverage = 0,
    this.levels = const [],
    this.result,
    this.frontHeading,
    this.tooFast = false,
    this.noSignal = false,
  });

  final DirectionPhase phase;

  /// Where the phone's top edge points now (degrees from north).
  final double? heading;
  final bool needsCalibration;
  final bool headingUnavailable;

  /// 0–1 share of directions measured.
  final double coverage;

  /// Mean RSSI per 10° bin (null = not measured).
  final List<double?> levels;
  final DirectionResult? result;

  /// Heading of the front of the hall, if set for this room.
  final double? frontHeading;

  /// Turning faster than the signal can be sampled.
  final bool tooFast;

  /// Nothing heard from the device for a while during the turn.
  final bool noSignal;

  DirectionState copyWith({
    DirectionPhase? phase,
    double? Function()? heading,
    bool? needsCalibration,
    bool? headingUnavailable,
    double? coverage,
    List<double?>? levels,
    DirectionResult? Function()? result,
    double? Function()? frontHeading,
    bool? tooFast,
    bool? noSignal,
  }) => DirectionState(
    phase: phase ?? this.phase,
    heading: heading != null ? heading() : this.heading,
    needsCalibration: needsCalibration ?? this.needsCalibration,
    headingUnavailable: headingUnavailable ?? this.headingUnavailable,
    coverage: coverage ?? this.coverage,
    levels: levels ?? this.levels,
    result: result != null ? result() : this.result,
    frontHeading: frontHeading != null ? frontHeading() : this.frontHeading,
    tooFast: tooFast ?? this.tooFast,
    noSignal: noSignal ?? this.noSignal,
  );
}

/// "Turn around to find the direction" for the radar's target: the body
/// shields the signal, so the strongest compass heading points at it.
class DirectionFinderViewModel extends Notifier<DirectionState> {
  /// A turn this complete finishes by itself.
  static const double autoFinishCoverage = 0.92;

  /// Gives up (and shows what it has) after this long.
  static const Duration maxTurn = Duration(seconds: 40);

  /// Faster than this (°/s) many directions get no packet at all.
  static const double maxTurnRate = 70;

  static const Duration _noSignalAfter = Duration(seconds: 3);

  late DirectionRepository _repo;
  late AppLogger _logger;
  late FinderAliases _aliases;
  late String _room;
  final DirectionFinder _finder = DirectionFinder();
  final List<double> _recent = [];
  StreamSubscription<HeadingReading>? _headingSub;
  StreamSubscription<RadarSignal>? _signalSub;
  Timer? _timeout;
  Timer? _silence;
  Set<String> _targets = const {};
  DateTime? _lastHeadingAt;
  DateTime _lastPublish = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  DirectionState build() {
    _repo = ref.watch(directionRepositoryProvider);
    _logger = ref.watch(appLoggerProvider);
    _aliases = FinderAliases(ref, _logger);
    _room = ref.read(sessionViewModelProvider)?.roomNumber ?? '';
    ref.onDispose(_stop);
    _headingSub = _repo.headings().listen(
      _onHeading,
      onError: (Object e, StackTrace st) {
        if (e is! HeadingUnavailableException) {
          _logger.warning('Heading stream failed', e, st);
        }
        if (ref.mounted) state = state.copyWith(headingUnavailable: true);
      },
    );
    return DirectionState(frontHeading: _repo.frontHeading(_room));
  }

  void _onHeading(HeadingReading h) {
    if (!ref.mounted) return;
    final now = DateTime.now();
    final previous = state.heading;
    var tooFast = state.tooFast;
    final last = _lastHeadingAt;
    if (previous != null && last != null) {
      final dt = now.difference(last).inMilliseconds / 1000;
      if (dt > 0) {
        tooFast = turnTo(previous, h.degrees).abs() / dt > maxTurnRate;
      }
    }
    _lastHeadingAt = now;
    _recent.add(h.degrees);
    if (_recent.length > 10) _recent.removeAt(0);
    // ~15 Hz is plenty for the dial.
    if (now.difference(_lastPublish).inMilliseconds < 66) return;
    _lastPublish = now;
    state = state.copyWith(
      heading: () => h.degrees,
      needsCalibration: h.needsCalibration,
      tooFast: state.phase == DirectionPhase.turning && tooFast,
    );
  }

  /// Starts a turn for [deviceId] (all of its addresses).
  void start(String deviceId) {
    if (state.headingUnavailable) return;
    _signalSub?.cancel();
    _finder.clear();
    _targets = _aliases.of(deviceId);
    state = state.copyWith(
      phase: DirectionPhase.turning,
      coverage: 0,
      levels: const [],
      result: () => null,
      noSignal: false,
      tooFast: false,
    );
    _signalSub = _repo
        .signals()
        .where((s) => _targets.contains(s.deviceId))
        .listen(_onSignal);
    _timeout?.cancel();
    _timeout = Timer(maxTurn, finish);
    _armSilence();
  }

  void _armSilence() {
    _silence?.cancel();
    _silence = Timer(_noSignalAfter, () {
      if (ref.mounted && state.phase == DirectionPhase.turning) {
        state = state.copyWith(noSignal: true);
      }
    });
  }

  void _onSignal(RadarSignal s) {
    final heading = state.heading;
    if (!ref.mounted || heading == null) return;
    _armSilence();
    _finder.add(heading, s.rssi);
    state = state.copyWith(
      coverage: _finder.coverage,
      levels: _finder.levels,
      noSignal: false,
    );
    if (_finder.coverage >= autoFinishCoverage) finish();
  }

  /// Ends the turn and works out the direction.
  void finish() {
    if (!ref.mounted || state.phase != DirectionPhase.turning) return;
    _signalSub?.cancel();
    _signalSub = null;
    _timeout?.cancel();
    _silence?.cancel();
    state = state.copyWith(
      phase: DirectionPhase.done,
      result: () => _finder.result(),
      tooFast: false,
      noSignal: false,
    );
  }

  void reset() {
    _signalSub?.cancel();
    _signalSub = null;
    _timeout?.cancel();
    _silence?.cancel();
    state = state.copyWith(
      phase: DirectionPhase.ready,
      coverage: 0,
      levels: const [],
      result: () => null,
      tooFast: false,
      noSignal: false,
    );
  }

  /// The phone's top edge points at the front of the hall now: remember
  /// that heading for this room. Returns false when it couldn't be saved.
  Future<bool> setFront() async {
    if (_recent.isEmpty) return false;
    final front = _circularMean(_recent);
    try {
      await _repo.saveFront(_room, front);
    } on StorageException catch (e, st) {
      _logger.warning('Front of hall not saved', e, st);
      return false;
    }
    if (ref.mounted) state = state.copyWith(frontHeading: () => front);
    return true;
  }

  static double _circularMean(List<double> degrees) {
    var x = 0.0, y = 0.0;
    for (final d in degrees) {
      x += math.cos(d * math.pi / 180);
      y += math.sin(d * math.pi / 180);
    }
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void _stop() {
    _headingSub?.cancel();
    _signalSub?.cancel();
    _timeout?.cancel();
    _silence?.cancel();
  }
}

final directionFinderViewModelProvider =
    NotifierProvider.autoDispose<DirectionFinderViewModel, DirectionState>(
      DirectionFinderViewModel.new,
    );
