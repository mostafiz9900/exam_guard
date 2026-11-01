import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/bluetooth/i_ble_gatt.dart';
import 'package:exam_guard/core/services/bluetooth/i_bluetooth_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/node_setup/model/node_setup_protocol.dart';

/// One Bluetooth setup connection to a node.
class NodeSetupLink {
  NodeSetupLink(this._link, this.info, this.networks);

  final BleGattLink _link;
  final NodeSetupInfo info;

  /// Wi-Fi networks the node saw when setup opened, strongest first.
  final List<NodeNetwork> networks;

  /// Completes when the node disconnects (it restarts after saving).
  Future<void> get done => _link.done;

  /// Asks the node to look for Wi-Fi again (~3 s) and returns what it sees.
  Future<List<NodeNetwork>> rescan() async {
    final ready = _link
        .notifications(NodeSetupProtocol.service, NodeSetupProtocol.status)
        .map(NodeSetupProtocol.decodeStatus)
        .where((u) => u?.status == NodeSetupStatus.ready)
        .first
        .timeout(const Duration(seconds: 15));
    await _link.write(
      NodeSetupProtocol.service,
      NodeSetupProtocol.config,
      NodeSetupProtocol.encodeScanRequest(),
    );
    await ready;
    return NodeSetupProtocol.decodeNetworks(
      await _link.read(NodeSetupProtocol.service, NodeSetupProtocol.networks),
    );
  }

  /// Sends [config] and emits the node's progress until it saves (or a
  /// step fails). The stream ends after [NodeSetupStatus.saved] or a
  /// failure; it errors when the link drops before either.
  Stream<NodeSetupUpdate> apply(NodeSetupConfig config) {
    late final StreamController<NodeSetupUpdate> out;
    StreamSubscription<List<int>>? sub;
    out = StreamController<NodeSetupUpdate>(
      onListen: () async {
        sub = _link
            .notifications(NodeSetupProtocol.service, NodeSetupProtocol.status)
            .listen(
              (bytes) {
                final u = NodeSetupProtocol.decodeStatus(bytes);
                if (u == null || out.isClosed) return;
                out.add(u);
                if (u.status == NodeSetupStatus.saved || u.status.isFailure) {
                  sub?.cancel();
                  out.close();
                }
              },
              onError: (Object e) {
                if (!out.isClosed) out.addError(e);
              },
            );
        unawaited(
          _link.done.then((_) {
            if (out.isClosed) return;
            out.addError(const BleGattException('Node disconnected'));
            out.close();
          }),
        );
        try {
          await _link.write(
            NodeSetupProtocol.service,
            NodeSetupProtocol.config,
            NodeSetupProtocol.encodeConfig(config),
          );
        } catch (e) {
          if (!out.isClosed) {
            out.addError(e);
            await out.close();
          }
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  Future<void> close() => _link.close();
}

/// Finds Pahara nodes in setup mode and talks to them over Bluetooth.
class NodeSetupRepository {
  NodeSetupRepository(this._ble, this._gatt, this._storage);

  final IBluetoothService _ble;
  final IBleGatt _gatt;
  final ILocalStorage _storage;

  static const String _scanOwner = 'node_setup';
  static const String _ssidKey = 'node_setup_last_ssid';

  /// A node not heard from this long is dropped from the list.
  static const Duration _stale = Duration(seconds: 8);

  Stream<BleAdapterStatus> adapterStatus() => _ble.adapterStatus();

  /// Nodes in setup mode nearby, strongest first. Scans while listened to.
  Stream<List<SetupNodeCandidate>> nearbyNodes() {
    final found = <String, SetupNodeCandidate>{};
    late final StreamController<List<SetupNodeCandidate>> out;
    StreamSubscription<BleScanRecord>? sub;
    Timer? prune;

    void emit() {
      final now = DateTime.now();
      found.removeWhere((_, c) => now.difference(c.lastSeen) > _stale);
      out.add(found.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi)));
    }

    out = StreamController<List<SetupNodeCandidate>>(
      onListen: () async {
        sub = _ble.scanRecords.listen(
          (r) {
            if (!NodeSetupProtocol.isSetupNode(r.name, r.serviceUuids)) return;
            final old = found[r.id];
            found[r.id] = SetupNodeCandidate(
              deviceId: r.id,
              // The name is in the scan response; keep it once known.
              name: r.name.isNotEmpty ? r.name : (old?.name ?? ''),
              rssi: r.rssi,
              lastSeen: r.timestamp,
            );
            emit();
          },
          onError: (Object e) {
            if (!out.isClosed) out.addError(e);
          },
        );
        prune = Timer.periodic(const Duration(seconds: 2), (_) => emit());
        try {
          await _ble.startScan(_scanOwner);
        } catch (e) {
          if (!out.isClosed) out.addError(e);
        }
      },
      onCancel: () async {
        prune?.cancel();
        await sub?.cancel();
        await _ble.stopScan(_scanOwner);
      },
    );
    return out.stream;
  }

  /// Connects to a node in setup mode and reads what it is and sees.
  /// Throws [BleGattException], or [StateError] for a device that isn't
  /// an Pahara node.
  Future<NodeSetupLink> connect(String deviceId) async {
    final link = await _gatt.open(deviceId);
    try {
      final info = NodeSetupProtocol.decodeInfo(
        await link.read(NodeSetupProtocol.service, NodeSetupProtocol.info),
      );
      if (info == null) throw StateError('Not an Pahara node');
      final networks = NodeSetupProtocol.decodeNetworks(
        await link.read(NodeSetupProtocol.service, NodeSetupProtocol.networks),
      );
      return NodeSetupLink(link, info, networks);
    } catch (_) {
      await link.close();
      rethrow;
    }
  }

  /// The hotspot used last time, so the next node is one tap. The password
  /// is never stored.
  String? get lastSsid => _storage.read<String>(_ssidKey);

  Future<void> rememberSsid(String ssid) async {
    try {
      await _storage.write(_ssidKey, ssid);
    } on StorageException {
      // Only a convenience.
    }
  }
}

final nodeSetupRepositoryProvider = Provider<NodeSetupRepository>(
  (ref) => NodeSetupRepository(
    ref.watch(bluetoothServiceProvider),
    ref.watch(bleGattProvider),
    ref.watch(localStorageProvider),
  ),
);
