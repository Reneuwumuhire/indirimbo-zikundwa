// Web transport: a browser can't run a server socket or do UDP discovery, so it
// cannot HOST or auto-discover. It CAN connect as a follower (WebSockets work in
// the browser), so joining by address / link is fully supported on web.

import 'dart:async';

import 'package:indirimbo/src/features/sharing/transport.dart';
import 'package:indirimbo/src/features/sharing/ws_client.dart';

bool get canHostSessions => false;
bool get canJoinSessions => true;

Future<ShareHost> startHost(
        {required String name, required SharedView initial, SharedSong? initialSong}) =>
    throw UnsupportedError('Hosting a session is not available on the web.');

Future<ShareClient> connectClient(DiscoveredSession session) => openWsClient(session);

/// No LAN discovery in the browser — return an empty (but valid) discovery so the
/// UI can still show the manual "join by address" path.
ShareDiscovery startDiscovery() => _EmptyDiscovery();

class _EmptyDiscovery implements ShareDiscovery {
  final _ctrl = StreamController<List<DiscoveredSession>>.broadcast();
  _EmptyDiscovery() {
    scheduleMicrotask(() {
      if (!_ctrl.isClosed) _ctrl.add(const []);
    });
  }
  @override
  Stream<List<DiscoveredSession>> get sessions => _ctrl.stream;
  @override
  Future<void> close() async {
    if (!_ctrl.isClosed) await _ctrl.close();
  }
}
