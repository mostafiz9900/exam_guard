import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/local_link/i_local_link.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/repository/hall_protocol.dart';
import 'package:exam_guard/features/hall/repository/hall_repository.dart';
import 'package:exam_guard/features/hall/view_model/node_alert_tracker.dart';
import 'package:exam_guard/features/scanner/model/scanned_device_model.dart';
import 'package:exam_guard/features/scanner/view_model/scanner_view_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

@immutable
class HallState {
  const HallState({
    this.role = HallRole.none,
    this.status = HallLinkStatus.idle,
    this.invite,
    this.room = '',
    this.members = const [],
    this.remoteDevices = const [],
    this.remoteAlerts = const [],
    this.offlineNodes = const [],
    this.errorKey,
    required this.selfId,
    required this.nodeKey,
  });

  final HallRole role;
  final HallLinkStatus status;

  /// What the host shows as a QR code (host only).
  final HallInvite? invite;
  final String room;

  /// Everyone in the hall, this phone included.
  final List<HallMember> members;

  /// Devices other members hear, strongest first.
  final List<RemoteDevice> remoteDevices;

  /// Alerts from other members, newest first.
  final List<RemoteAlert> remoteAlerts;

  /// Nodes that were in the hall and are gone now, oldest first.
  final List<OfflineNode> offlineNodes;

  /// Translation key of the last problem, or null.
  final String? errorKey;
  final String selfId;

  /// Key for ESP32 nodes joining halls hosted by this phone.
  final String nodeKey;

  bool get isActive => role != HallRole.none;

  List<RemoteAlert> get pendingAlerts => [
    for (final a in remoteAlerts)
      if (!a.alert.acknowledged) a,
  ];

  int get nodeCount =>
      members.where((m) => m.kind == HallMemberKind.node).length;

  HallState copyWith({
    HallRole? role,
    HallLinkStatus? status,
    HallInvite? Function()? invite,
    String? room,
    List<HallMember>? members,
    List<RemoteDevice>? remoteDevices,
    List<RemoteAlert>? remoteAlerts,
    List<OfflineNode>? offlineNodes,
    String? Function()? errorKey,
    String? nodeKey,
  }) => HallState(
    role: role ?? this.role,
    status: status ?? this.status,
    invite: invite != null ? invite() : this.invite,
    room: room ?? this.room,
    members: members ?? this.members,
    remoteDevices: remoteDevices ?? this.remoteDevices,
    remoteAlerts: remoteAlerts ?? this.remoteAlerts,
    offlineNodes: offlineNodes ?? this.offlineNodes,
    errorKey: errorKey != null ? errorKey() : this.errorKey,
    selfId: selfId,
    nodeKey: nodeKey ?? this.nodeKey,
  );
}

/// One exam hall shared by several invigilator phones and ESP32 nodes.
///
/// The host runs the hub; every member (host included) publishes the
/// devices its scanner hears and its new-device alerts, and the hub relays
/// them to everyone else. Lives for the whole exam (not autoDispose) and
/// leaves the hall by itself when the exam ends.
class HallViewModel extends Notifier<HallState> {
  static const Duration publishEvery = Duration(seconds: 2);

  /// A source silent this long no longer counts as hearing its devices.
  static const Duration remoteStaleAfter = Duration(seconds: 30);

  /// Only devices about inside the hall are shared.
  static const int minSharedRssi = -90;
  static const int maxRemoteAlerts = 50;
  static const List<Duration> _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 15),
  ];

  late HallRepository _repo;
  late AppLogger _logger;

  final List<StreamSubscription<Object?>> _subs = [];
  ProviderSubscription<ScannerState>? _scannerSub;
  Timer? _publishTimer;
  Timer? _staleTimer;
  Timer? _retryTimer;
  int _retry = 0;

  String _token = '';
  HallInvite? _joined;
  final Map<String, HallMember> _members = {};
  final Map<String, RemoteDevice> _remote = {};
  List<ScannedDeviceModel> _localDevices = const [];
  final Set<String> _sentAlerts = {};
  ScannerState? _latestScan;
  final NodeAlertTracker _nodeAlerts = NodeAlertTracker();

  /// Every node seen in this hall, so one that disappears can be flagged.
  final Map<String, HallMember> _everNodes = {};
  final Map<String, OfflineNode> _offline = {};

  @override
  HallState build() {
    _repo = ref.watch(hallRepositoryProvider);
    _logger = ref.watch(appLoggerProvider);
    ref.listen(sessionViewModelProvider.select((s) => s?.isActive ?? false), (
      _,
      active,
    ) {
      if (!active) unawaited(leave());
    });
    ref.onDispose(_teardown);
    return HallState(selfId: _repo.memberId, nodeKey: _repo.nodeKey);
  }

  HallMember _self({required bool isHost}) => HallMember(
    id: state.selfId,
    name: ref.read(sessionViewModelProvider)?.teacherName.trim() ?? '',
    kind: HallMemberKind.phone,
    isHost: isHost,
  );

  bool _examRunning() => ref.read(sessionViewModelProvider)?.isActive ?? false;

  // ── Host ──────────────────────────────────────────────────────────────

  Future<void> host() async {
    if (state.isActive) return;
    if (!_examRunning()) {
      state = state.copyWith(errorKey: () => 'hall_err_no_exam');
      return;
    }
    state = state.copyWith(
      role: HallRole.host,
      status: HallLinkStatus.starting,
      errorKey: () => null,
    );
    final ip = await _repo.localIpv4();
    if (!ref.mounted || state.role != HallRole.host) return;
    if (ip == null) {
      _fail('hall_err_no_network');
      return;
    }

    _token = _repo.newToken();
    _subs
      ..add(_repo.hub.peers.listen(_onPeer))
      ..add(_repo.hub.messages.listen(_onHubMessage));
    int port;
    try {
      port = await _startHub(HallRepository.defaultPort);
    } catch (_) {
      // Port taken (another app): phones can still join on any port.
      try {
        port = await _startHub(0);
      } catch (e, st) {
        _logger.warning('Hall hub failed to start', e, st);
        if (ref.mounted) _fail('hall_err_start_failed');
        return;
      }
    }
    if (!ref.mounted || state.role != HallRole.host) return;

    final room = ref.read(sessionViewModelProvider)?.roomNumber ?? '';
    final me = _self(isHost: true);
    _members
      ..clear()
      ..[me.id] = me;
    state = state.copyWith(
      status: HallLinkStatus.hosting,
      room: room,
      invite: () => HallInvite(host: ip, port: port, token: _token, room: room),
      members: _memberList(),
    );
    _startSharing();
  }

  Future<int> _startHub(int port) => _repo.hub.start(
    port: port,
    accept: _accept,
    rejectReply: (hello) => HallProtocol.encodeReject(_rejectReason(hello)),
  );

  String _rejectReason(Map<String, Object?> hello) {
    if (hello['v'] != HallProtocol.version) return HallProtocol.badVersion;
    if (HallMember.fromJson(hello['member']) == null) {
      return HallProtocol.badHello;
    }
    return HallProtocol.badToken;
  }

  String? _accept(Map<String, Object?> hello) {
    if (HallProtocol.typeOf(hello) != HallProtocol.hello) return null;
    if (hello['v'] != HallProtocol.version) return null;
    final member = HallMember.fromJson(hello['member']);
    if (member == null || member.id == state.selfId) return null;
    final token = hello['token'];
    final ok = member.kind == HallMemberKind.node
        ? token == state.nodeKey
        : token == _token;
    return ok ? member.id : null;
  }

  void _onPeer(LinkPeerEvent e) {
    if (!ref.mounted || state.role != HallRole.host) return;
    if (e.joined) {
      final m = HallMember.fromJson(e.hello!['member']);
      if (m == null) return;
      _members[e.peerId] = HallMember(id: e.peerId, name: m.name, kind: m.kind);
      _repo.hub.sendTo(
        e.peerId,
        HallProtocol.encodeWelcome(state.room, _memberList()),
      );
    } else {
      _members.remove(e.peerId);
      _remote.removeWhere((_, d) => d.sourceId == e.peerId);
    }
    _repo.hub.broadcast(HallProtocol.encodeMembers(_memberList()));
    state = state.copyWith(
      members: _memberList(),
      remoteDevices: _remoteList(),
      offlineNodes: _updateNodePresence(),
    );
  }

  void _onHubMessage(LinkMessage m) {
    if (!ref.mounted || state.role != HallRole.host) return;
    final type = HallProtocol.typeOf(m.json);
    if (type != HallProtocol.sightings && type != HallProtocol.alert) return;
    // The hub, not the sender, says who sent it.
    final relayed = {...m.json, 'from': m.peerId};
    _repo.hub.broadcast(relayed, except: m.peerId);
    _apply(relayed);
    if (type == HallProtocol.sightings &&
        _members[m.peerId]?.kind == HallMemberKind.node) {
      _alertForNode(m.peerId, relayed);
    }
  }

  /// Nodes don't raise alerts themselves: the host applies the phone
  /// scanner's rules (and its baseline / trusted list) to what they hear.
  void _alertForNode(String nodeId, Map<String, Object?> sightings) {
    final scan = _latestScan;
    final alerts = _nodeAlerts.onSightings(
      nodeId: nodeId,
      devices: HallProtocol.decodeSightings(sightings),
      now: DateTime.now(),
      baselineAt: scan?.baselineAt,
      isTrusted: (id) => scan?.isTrusted(id) ?? false,
    );
    for (final a in alerts) {
      final msg = HallProtocol.encodeAlert(nodeId, a);
      _repo.hub.broadcast(msg);
      _apply(msg);
    }
  }

  // ── Member ────────────────────────────────────────────────────────────

  /// Joins the hall in a scanned (or typed) invite.
  Future<void> join(String inviteText) async {
    if (state.isActive) return;
    final invite = HallInvite.parse(inviteText);
    if (invite == null) {
      state = state.copyWith(errorKey: () => 'hall_err_bad_code');
      return;
    }
    if (!_examRunning()) {
      state = state.copyWith(errorKey: () => 'hall_err_no_exam');
      return;
    }
    _joined = invite;
    _retry = 0;
    state = state.copyWith(
      role: HallRole.member,
      status: HallLinkStatus.connecting,
      room: invite.room,
      errorKey: () => null,
    );
    _subs
      ..add(_repo.client.messages.listen(_onClientMessage))
      ..add(_repo.client.state.listen(_onClientState));
    await _connect();
  }

  Future<void> _connect() async {
    final invite = _joined;
    if (invite == null || !ref.mounted) return;
    try {
      await _repo.client.connect(
        invite.socketUri,
        HallProtocol.encodeHello(_self(isHost: false), invite.token),
      );
    } catch (e) {
      _logger.debug('Hall connect failed: $e');
      if (ref.mounted && state.role == HallRole.member) _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delay = _retryDelays[_retry.clamp(0, _retryDelays.length - 1)];
    _retry++;
    state = state.copyWith(
      status: HallLinkStatus.reconnecting,
      errorKey: () => 'hall_err_unreachable',
    );
    _retryTimer = Timer(delay, () => unawaited(_connect()));
  }

  void _onClientState(LinkClientState s) {
    if (!ref.mounted || state.role != HallRole.member) return;
    if (s == LinkClientState.disconnected &&
        state.status != HallLinkStatus.failed &&
        _retryTimer?.isActive != true) {
      _scheduleRetry();
    }
  }

  void _onClientMessage(Map<String, Object?> json) {
    if (!ref.mounted || state.role != HallRole.member) return;
    switch (HallProtocol.typeOf(json)) {
      case HallProtocol.welcome:
        _retry = 0;
        _setMembers(HallProtocol.decodeMembers(json));
        state = state.copyWith(
          status: HallLinkStatus.connected,
          room: json['room'] is String ? json['room']! as String : null,
          errorKey: () => null,
          members: _memberList(),
          offlineNodes: _updateNodePresence(),
        );
        _startSharing();
      case HallProtocol.reject:
        final reason = json['reason'];
        _retryTimer?.cancel();
        unawaited(_repo.client.disconnect());
        _fail(
          reason == HallProtocol.badVersion
              ? 'hall_err_old_version'
              : 'hall_err_rejected',
        );
      case HallProtocol.members:
        _setMembers(HallProtocol.decodeMembers(json));
        _remote.removeWhere((_, d) => !_members.containsKey(d.sourceId));
        state = state.copyWith(
          members: _memberList(),
          remoteDevices: _remoteList(),
          offlineNodes: _updateNodePresence(),
        );
      case HallProtocol.sightings || HallProtocol.alert:
        _apply(json);
    }
  }

  void _setMembers(List<HallMember> members) {
    _members
      ..clear()
      ..addEntries(members.map((m) => MapEntry(m.id, m)));
  }

  // ── Sharing (both roles) ──────────────────────────────────────────────

  void _startSharing() {
    _scannerSub ??= ref.listen<ScannerState>(
      scannerViewModelProvider,
      (_, s) => _onLocalScan(s),
      fireImmediately: true,
    );
    _publishTimer ??= Timer.periodic(publishEvery, (_) => _publishSightings());
    _staleTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => _dropStale(),
    );
  }

  void _send(Map<String, Object?> json) {
    if (state.role == HallRole.host) {
      _repo.hub.broadcast(json);
    } else if (state.status == HallLinkStatus.connected) {
      _repo.client.send(json);
    }
  }

  void _onLocalScan(ScannerState s) {
    _latestScan = s;
    _localDevices = s.devices;
    for (final a in s.alerts) {
      final key = '${a.deviceId}@${a.detectedAt.millisecondsSinceEpoch}';
      if (_sentAlerts.add(key)) {
        _send(HallProtocol.encodeAlert(state.selfId, a));
      }
    }
  }

  /// Shares the strongest devices this phone hears right now.
  @visibleForTesting
  void publishSightingsNow() => _publishSightings();

  void _publishSightings() {
    if (!ref.mounted || !state.status.isLive) return;
    final now = DateTime.now();
    final shared =
        _localDevices
            .where(
              (d) =>
                  d.rssi >= minSharedRssi &&
                  now.difference(d.lastSeen) < remoteStaleAfter,
            )
            .toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
    _send(
      HallProtocol.encodeSightings(
        state.selfId,
        shared.take(HallProtocol.maxSightings).toList(),
      ),
    );
  }

  void _apply(Map<String, Object?> json) {
    final from = HallProtocol.fromOf(json);
    if (from == null || from == state.selfId) return;
    final source = _members[from]?.name ?? from;
    final now = DateTime.now();
    switch (HallProtocol.typeOf(json)) {
      case HallProtocol.sightings:
        // A batch is the source's complete current list.
        _remote.removeWhere((_, d) => d.sourceId == from);
        for (final d in HallProtocol.decodeSightings(json)) {
          final r = RemoteDevice(
            device: d,
            sourceId: from,
            sourceName: source,
            receivedAt: now,
          );
          _remote[r.key] = r;
        }
        state = state.copyWith(remoteDevices: _remoteList());
      case HallProtocol.alert:
        final alert = HallProtocol.decodeAlert(json);
        if (alert == null) return;
        _addRemoteAlert(
          RemoteAlert(alert: alert, sourceId: from, sourceName: source),
        );
    }
  }

  void _addRemoteAlert(RemoteAlert a) {
    final rest = state.remoteAlerts.where((x) => x.key != a.key);
    state = state.copyWith(
      remoteAlerts: [a, ...rest].take(maxRemoteAlerts).toList(),
    );
  }

  void _dropStale() {
    if (!ref.mounted) return;
    final now = DateTime.now();
    final before = _remote.length;
    _remote.removeWhere(
      (_, d) => now.difference(d.receivedAt) > remoteStaleAfter,
    );
    if (_remote.length != before) {
      state = state.copyWith(remoteDevices: _remoteList());
    }
  }

  void acknowledgeRemoteAlert(String key) {
    state = state.copyWith(
      remoteAlerts: [
        for (final a in state.remoteAlerts) a.key == key ? a.acknowledged() : a,
      ],
    );
  }

  void acknowledgeAllRemoteAlerts() {
    state = state.copyWith(
      remoteAlerts: [for (final a in state.remoteAlerts) a.acknowledged()],
    );
  }

  /// Makes a new node key; nodes must be reconfigured with it.
  Future<void> regenerateNodeKey() async {
    final key = await _repo.regenerateNodeKey();
    if (ref.mounted) state = state.copyWith(nodeKey: key);
  }

  /// Marks nodes that left as offline and clears those that came back.
  List<OfflineNode> _updateNodePresence() {
    final now = DateTime.now();
    final present = {
      for (final m in _members.values)
        if (m.kind == HallMemberKind.node) m.id: m,
    };
    _everNodes.addAll(present);
    _offline.removeWhere((id, _) => present.containsKey(id));
    for (final e in _everNodes.entries) {
      if (!present.containsKey(e.key)) {
        _offline.putIfAbsent(
          e.key,
          () => OfflineNode(member: e.value, since: now),
        );
      }
    }
    return List.unmodifiable(
      _offline.values.toList()..sort((a, b) => a.since.compareTo(b.since)),
    );
  }

  /// The invigilator removed this node on purpose: stop warning about it.
  void dismissOfflineNode(String nodeId) {
    _everNodes.remove(nodeId);
    _offline.remove(nodeId);
    _nodeAlerts.forgetNode(nodeId);
    state = state.copyWith(
      offlineNodes: [
        for (final n in state.offlineNodes)
          if (n.member.id != nodeId) n,
      ],
    );
  }

  List<HallMember> _memberList() {
    final list = _members.values.toList()
      ..sort((a, b) {
        if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
        if (a.kind != b.kind) return a.kind.index.compareTo(b.kind.index);
        return a.name.compareTo(b.name);
      });
    return List.unmodifiable(list);
  }

  List<RemoteDevice> _remoteList() => List.unmodifiable(
    _remote.values.toList()
      ..sort((a, b) => b.device.rssi.compareTo(a.device.rssi)),
  );

  // ── Leaving ───────────────────────────────────────────────────────────

  void _fail(String errorKey) {
    _stopAll();
    state = HallState(
      selfId: state.selfId,
      nodeKey: state.nodeKey,
      status: HallLinkStatus.failed,
      errorKey: errorKey,
    );
  }

  /// Leaves (or, as host, closes) the hall.
  Future<void> leave() async {
    if (!state.isActive && state.status != HallLinkStatus.failed) return;
    _stopAll();
    state = HallState(selfId: state.selfId, nodeKey: state.nodeKey);
  }

  void _stopAll() {
    final wasHost = state.role == HallRole.host;
    _teardown();
    if (wasHost) {
      unawaited(_repo.hub.stop());
    } else {
      unawaited(_repo.client.disconnect());
    }
  }

  void _teardown() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _scannerSub?.close();
    _scannerSub = null;
    _publishTimer?.cancel();
    _publishTimer = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _joined = null;
    _members.clear();
    _remote.clear();
    _sentAlerts.clear();
    _localDevices = const [];
    _latestScan = null;
    _nodeAlerts.reset();
    _everNodes.clear();
    _offline.clear();
  }
}

final hallViewModelProvider = NotifierProvider<HallViewModel, HallState>(
  HallViewModel.new,
);
