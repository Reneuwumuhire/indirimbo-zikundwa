// dart:io implementation of the share transport (mobile / desktop).
//
// Host  = an HttpServer upgraded to WebSocket + a periodic UDP broadcast beacon.
// Client = a WebSocket connection.
// Discovery = a UDP listener on the well-known beacon port.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'transport.dart';
import 'ws_client.dart';

bool get canHostSessions => true;
bool get canJoinSessions => true;

Future<ShareHost> startHost({required String name, required SharedView initial}) async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
  final addresses = await _localIpv4s();
  return _IoHost(server, name, initial, addresses);
}

Future<ShareClient> connectClient(DiscoveredSession session) => openWsClient(session);

ShareDiscovery startDiscovery() => _IoDiscovery();

/// The device's non-loopback IPv4 addresses (for building join URLs).
Future<List<String>> _localIpv4s() async {
  try {
    final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    return [for (final i in ifaces) for (final a in i.addresses) a.address];
  } catch (_) {
    return const [];
  }
}

class _IoHost implements ShareHost {
  final HttpServer _server;
  final String name;
  SharedView _current;
  final List<String> _addresses;

  final _clients = <WebSocket>{};
  final _countCtrl = StreamController<int>.broadcast();
  RawDatagramSocket? _beacon;
  Timer? _beaconTimer;

  _IoHost(this._server, this.name, this._current, this._addresses) {
    _server.listen(_onRequest);
    _startBeacon();
  }

  @override
  int get wsPort => _server.port;

  @override
  List<String> get joinUrls => [for (final a in _addresses) 'ws://$a:${_server.port}'];

  @override
  Stream<int> get clientCount => _countCtrl.stream;

  Future<void> _onRequest(HttpRequest req) async {
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response.statusCode = HttpStatus.forbidden;
      await req.response.close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(req);
    _clients.add(ws);
    _emitCount();
    ws.add(ShareMessage.hello(name, _current).encode());
    void drop() {
      if (_clients.remove(ws)) _emitCount();
    }

    ws.listen((_) {}, onDone: drop, onError: (_) => drop(), cancelOnError: true);
  }

  void _emitCount() {
    if (!_countCtrl.isClosed) _countCtrl.add(_clients.length);
  }

  @override
  void update(SharedView view) {
    _current = view;
    final msg = ShareMessage.viewUpdate(view).encode();
    for (final c in _clients) {
      try {
        c.add(msg);
      } catch (_) {/* client mid-disconnect */}
    }
  }

  Future<void> _startBeacon() async {
    try {
      final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sock.broadcastEnabled = true;
      _beacon = sock;
      final broadcast = InternetAddress('255.255.255.255');
      void ping() {
        try {
          final data = utf8.encode(ShareBeacon(name: name, wsPort: wsPort).encode());
          sock.send(data, broadcast, kDiscoveryPort);
        } catch (_) {/* transient network error */}
      }

      ping();
      _beaconTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => ping());
    } catch (_) {/* discovery unavailable; manual connect still works */}
  }

  @override
  Future<void> close() async {
    _beaconTimer?.cancel();
    _beacon?.close();
    for (final c in _clients) {
      try {
        c.add(ShareMessage.bye().encode());
        await c.close();
      } catch (_) {}
    }
    _clients.clear();
    if (!_countCtrl.isClosed) await _countCtrl.close();
    await _server.close(force: true);
  }
}

class _IoDiscovery implements ShareDiscovery {
  RawDatagramSocket? _sock;
  final _ctrl = StreamController<List<DiscoveredSession>>.broadcast();
  final _seen = <DiscoveredSession, DateTime>{};
  Timer? _sweep;

  _IoDiscovery() {
    _start();
  }

  Future<void> _start() async {
    try {
      _sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kDiscoveryPort,
          reuseAddress: true);
      _sock!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = _sock!.receive();
        if (dg == null) return;
        final beacon = ShareBeacon.tryDecode(utf8.decode(dg.data));
        if (beacon == null) return;
        final session = DiscoveredSession(
            name: beacon.name, host: dg.address.address, wsPort: beacon.wsPort);
        _seen[session] = DateTime.now();
        _emit();
      });
      // Expire sessions whose beacon stopped (~5s without a ping).
      _sweep = Timer.periodic(const Duration(seconds: 2), (_) {
        final now = DateTime.now();
        final before = _seen.length;
        _seen.removeWhere((_, seen) => now.difference(seen).inSeconds > 5);
        if (_seen.length != before) _emit();
      });
    } catch (_) {/* discovery port busy / unavailable */}
  }

  void _emit() {
    if (!_ctrl.isClosed) _ctrl.add(_seen.keys.toList());
  }

  @override
  Stream<List<DiscoveredSession>> get sessions => _ctrl.stream;

  @override
  Future<void> close() async {
    _sweep?.cancel();
    _sock?.close();
    if (!_ctrl.isClosed) await _ctrl.close();
  }
}
