import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';
import 'package:exam_guard/features/node_setup/model/node_setup_protocol.dart';
import 'package:exam_guard/features/node_setup/repository/node_setup_repository.dart';

/// Where the "Add a sensor node" wizard is.
enum NodeSetupStep {
  /// Power the node; make sure it is in setup mode.
  prepare,

  /// Looking for nodes in setup mode over Bluetooth.
  search,

  /// Connected: choose the hotspot and enter its password.
  wifi,

  /// The node is testing the Wi-Fi and the host phone.
  applying,

  /// Saved; the node restarts and joins the hall.
  done,
}

/// What was typed into the Wi-Fi form, kept for a retry after a failure
/// and for the next node (same hotspot). Memory only — never stored.
@immutable
class NodeWifiDraft {
  const NodeWifiDraft({
    required this.ssid,
    required this.password,
    required this.isManual,
    this.name = '',
    this.hub = '',
  });

  final String ssid;
  final String password;

  /// Typed by name rather than picked from the node's list.
  final bool isManual;
  final String name;
  final String hub;
}

@immutable
class NodeSetupState {
  const NodeSetupState({
    this.step = NodeSetupStep.prepare,
    this.candidates = const [],
    this.bluetoothOff = false,
    this.connectingId,
    this.info,
    this.networks = const [],
    this.isRescanning = false,
    this.suggestedSsid,
    this.progress = const [],
    this.failure,
    this.failedSsid,
    this.errorKey,
    this.savedName,
    this.hostReachable,
    this.draft,
  });

  final NodeSetupStep step;

  /// Nodes in setup mode nearby, strongest first.
  final List<SetupNodeCandidate> candidates;
  final bool bluetoothOff;

  /// Bluetooth id being connected to, while connecting.
  final String? connectingId;

  /// The connected node.
  final NodeSetupInfo? info;

  /// Wi-Fi networks the node sees.
  final List<NodeNetwork> networks;
  final bool isRescanning;

  /// Hotspot to preselect: the one used last time, if the node sees it.
  final String? suggestedSsid;

  /// Statuses the node reported for the current attempt, in order.
  final List<NodeSetupStatus> progress;

  /// The step that failed, while [step] is [NodeSetupStep.applying].
  final NodeSetupStatus? failure;
  final String? failedSsid;

  /// Translation key of a problem to show, or null.
  final String? errorKey;

  /// The node's name once saved.
  final String? savedName;

  /// Whether the node reached this phone's hall during setup. False just
  /// means the hall wasn't hosted yet.
  final bool? hostReachable;

  /// The last Wi-Fi details sent.
  final NodeWifiDraft? draft;

  bool get isConnecting => connectingId != null;

  NodeSetupState copyWith({
    NodeSetupStep? step,
    List<SetupNodeCandidate>? candidates,
    bool? bluetoothOff,
    String? Function()? connectingId,
    NodeSetupInfo? Function()? info,
    List<NodeNetwork>? networks,
    bool? isRescanning,
    String? Function()? suggestedSsid,
    List<NodeSetupStatus>? progress,
    NodeSetupStatus? Function()? failure,
    String? Function()? failedSsid,
    String? Function()? errorKey,
    String? Function()? savedName,
    bool? Function()? hostReachable,
    NodeWifiDraft? draft,
  }) => NodeSetupState(
    step: step ?? this.step,
    candidates: candidates ?? this.candidates,
    bluetoothOff: bluetoothOff ?? this.bluetoothOff,
    connectingId: connectingId != null ? connectingId() : this.connectingId,
    info: info != null ? info() : this.info,
    networks: networks ?? this.networks,
    isRescanning: isRescanning ?? this.isRescanning,
    suggestedSsid: suggestedSsid != null ? suggestedSsid() : this.suggestedSsid,
    progress: progress ?? this.progress,
    failure: failure != null ? failure() : this.failure,
    failedSsid: failedSsid != null ? failedSsid() : this.failedSsid,
    errorKey: errorKey != null ? errorKey() : this.errorKey,
    savedName: savedName != null ? savedName() : this.savedName,
    hostReachable: hostReachable != null ? hostReachable() : this.hostReachable,
    draft: draft ?? this.draft,
  );
}

/// Sets up one Pahara ESP32 node over Bluetooth: find it, send the
/// hotspot and this phone's node key, follow the node's own Wi-Fi test.
class NodeSetupViewModel extends Notifier<NodeSetupState> {
  /// WPA2 passwords are 8–63 characters.
  static const int minPasswordLength = 8;

  late NodeSetupRepository _repo;
  late AppLogger _logger;
  StreamSubscription<List<SetupNodeCandidate>>? _searchSub;
  StreamSubscription<BleAdapterStatus>? _adapterSub;
  StreamSubscription<NodeSetupUpdate>? _applySub;
  NodeSetupLink? _link;

  @override
  NodeSetupState build() {
    _repo = ref.watch(nodeSetupRepositoryProvider);
    _logger = ref.watch(appLoggerProvider);
    ref.onDispose(() {
      _stopSearch();
      _adapterSub?.cancel();
      _applySub?.cancel();
      final link = _link;
      _link = null;
      if (link != null) unawaited(link.close());
    });
    return const NodeSetupState();
  }

  /// Starts (or restarts) looking for nodes in setup mode.
  void startSearch() {
    _stopSearch();
    state = state.copyWith(
      step: NodeSetupStep.search,
      candidates: const [],
      errorKey: () => null,
    );
    _adapterSub ??= _repo.adapterStatus().listen((s) {
      if (!ref.mounted) return;
      state = state.copyWith(bluetoothOff: s != BleAdapterStatus.on);
    });
    _searchSub = _repo.nearbyNodes().listen(
      (list) {
        if (!ref.mounted || state.step != NodeSetupStep.search) return;
        state = state.copyWith(candidates: list);
      },
      onError: (Object e, StackTrace st) {
        _logger.warning('Node search failed', e, st);
        if (ref.mounted) {
          state = state.copyWith(errorKey: () => 'node_err_search');
        }
      },
    );
  }

  void _stopSearch() {
    _searchSub?.cancel();
    _searchSub = null;
  }

  /// Connects to [candidate] and moves on to the Wi-Fi step.
  Future<void> select(SetupNodeCandidate candidate) async {
    if (state.isConnecting) return;
    // Scanning while connecting slows the connection down on Android.
    _stopSearch();
    state = state.copyWith(
      connectingId: () => candidate.deviceId,
      errorKey: () => null,
    );
    try {
      final link = await _repo.connect(candidate.deviceId);
      if (!ref.mounted) {
        unawaited(link.close());
        return;
      }
      _link = link;
      final last = state.draft?.ssid ?? _repo.lastSsid;
      final saved = link.info.savedSsid;
      final seen = {for (final n in link.networks) n.ssid};
      state = state.copyWith(
        step: NodeSetupStep.wifi,
        connectingId: () => null,
        info: () => link.info,
        networks: link.networks,
        suggestedSsid: () => last != null && seen.contains(last)
            ? last
            : saved != null && seen.contains(saved)
            ? saved
            : null,
      );
      unawaited(link.done.then((_) => _onLinkLost(link)));
    } catch (e, st) {
      _logger.warning('Node connect failed', e, st);
      if (!ref.mounted) return;
      state = state.copyWith(connectingId: () => null);
      startSearch();
      state = state.copyWith(errorKey: () => 'node_err_connect');
    }
  }

  void _onLinkLost(NodeSetupLink link) {
    if (!ref.mounted || _link != link) return;
    _link = null;
    // After "saved" the node restarts: that is the expected goodbye.
    if (state.step == NodeSetupStep.done) return;
    _applySub?.cancel();
    _applySub = null;
    state = state.copyWith(
      step: NodeSetupStep.prepare,
      info: () => null,
      progress: const [],
      failure: () => null,
      errorKey: () => 'node_err_lost',
    );
  }

  /// Asks the node to look for Wi-Fi networks again.
  Future<void> rescanNetworks() async {
    final link = _link;
    if (link == null || state.isRescanning) return;
    state = state.copyWith(isRescanning: true);
    try {
      final networks = await link.rescan();
      if (ref.mounted) state = state.copyWith(networks: networks);
    } catch (e, st) {
      _logger.warning('Node Wi-Fi rescan failed', e, st);
    } finally {
      if (ref.mounted) state = state.copyWith(isRescanning: false);
    }
  }

  /// Translation key of what is wrong with these Wi-Fi details, or null.
  String? validate({required String ssid, required String password}) {
    if (ssid.trim().isEmpty) return 'node_err_ssid_required';
    final known = state.networks.where((n) => n.ssid == ssid.trim());
    final open = known.isNotEmpty && known.first.isOpen;
    if (open) return null;
    if (password.isEmpty) return 'node_err_password_required';
    if (password.length < minPasswordLength) {
      return 'node_err_password_short';
    }
    return null;
  }

  /// Sends the settings; the node tests them and reports back.
  void submit({
    required String ssid,
    required String password,
    String name = '',
    String hub = '',
    bool isManual = false,
  }) {
    final link = _link;
    if (link == null) return;
    state = state.copyWith(
      draft: NodeWifiDraft(
        ssid: ssid.trim(),
        password: password,
        isManual: isManual,
        name: name,
        hub: hub,
      ),
    );
    final problem = validate(ssid: ssid, password: password);
    if (problem != null) {
      state = state.copyWith(errorKey: () => problem);
      return;
    }
    final config = NodeSetupConfig(
      ssid: ssid.trim(),
      password: password,
      nodeKey: ref.read(hallViewModelProvider).nodeKey,
      name: name.trim(),
      hub: hub.trim(),
    );
    _applySub?.cancel();
    state = state.copyWith(
      step: NodeSetupStep.applying,
      progress: const [],
      failure: () => null,
      failedSsid: () => null,
      errorKey: () => null,
      hostReachable: () => null,
    );
    _applySub = link
        .apply(config)
        .listen(
          (u) => _onUpdate(u, config),
          onError: (Object e, StackTrace st) {
            _logger.warning('Node setup failed', e, st);
            if (!ref.mounted || state.step != NodeSetupStep.applying) return;
            state = state.copyWith(
              failure: () => NodeSetupStatus.wifiFailed,
              errorKey: () => 'node_err_lost',
            );
          },
        );
  }

  void _onUpdate(NodeSetupUpdate u, NodeSetupConfig config) {
    if (!ref.mounted) return;
    final progress = [...state.progress, u.status];
    switch (u.status) {
      case NodeSetupStatus.saved:
        unawaited(_repo.rememberSsid(config.ssid));
        state = state.copyWith(
          step: NodeSetupStep.done,
          progress: progress,
          savedName: () => u.detail ?? state.info?.name,
        );
        // The node restarts by itself; let go of the link.
        final link = _link;
        _link = null;
        if (link != null) unawaited(link.close());
      case NodeSetupStatus.hostOk || NodeSetupStatus.noHost:
        state = state.copyWith(
          progress: progress,
          hostReachable: () => u.status == NodeSetupStatus.hostOk,
        );
      case _ when u.status.isFailure:
        state = state.copyWith(
          progress: progress,
          failure: () => u.status,
          failedSsid: () => u.detail ?? config.ssid,
        );
      case _:
        state = state.copyWith(progress: progress);
    }
  }

  /// Back to the Wi-Fi form after a failed attempt (still connected).
  void editWifi() {
    if (_link == null) {
      state = state.copyWith(step: NodeSetupStep.prepare);
      return;
    }
    state = state.copyWith(
      step: NodeSetupStep.wifi,
      progress: const [],
      failure: () => null,
      errorKey: () => null,
    );
  }

  void clearError() => state = state.copyWith(errorKey: () => null);

  /// Starts over for the next node, keeping the hotspot and password
  /// (not the name) so it is one tap.
  void addAnother() {
    _applySub?.cancel();
    _applySub = null;
    final link = _link;
    _link = null;
    if (link != null) unawaited(link.close());
    final d = state.draft;
    state = NodeSetupState(
      bluetoothOff: state.bluetoothOff,
      draft: d == null
          ? null
          : NodeWifiDraft(
              ssid: d.ssid,
              password: d.password,
              isManual: d.isManual,
              hub: d.hub,
            ),
    );
  }
}

final nodeSetupViewModelProvider =
    NotifierProvider.autoDispose<NodeSetupViewModel, NodeSetupState>(
      NodeSetupViewModel.new,
    );
