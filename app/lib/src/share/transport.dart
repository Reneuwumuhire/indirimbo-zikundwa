// Platform-agnostic surface for the local-network share transport.
//
// The real implementation uses dart:io (a WebSocket server + a UDP discovery
// beacon) and is selected on mobile/desktop. On web there is no socket server,
// so a stub reports the feature as unsupported. This conditional import keeps
// the web build compiling.

import 'share_messages.dart';

export 'share_messages.dart';

import 'transport_web.dart' if (dart.library.io) 'transport_io.dart' as impl;

/// Whether this platform can *host* a session (false on web — no server socket).
bool get canHostSessions => impl.canHostSessions;

/// Whether this platform can *join* a session (true everywhere, incl. web).
bool get canJoinSessions => impl.canJoinSessions;

/// Whether sharing is available at all (host or join).
bool get isShareSupported => canHostSessions || canJoinSessions;

/// Start hosting a session; broadcasts [initial] until [ShareHost.update] is
/// called. [initialSong] is the full content of [initial]'s song, used to render
/// the browser follow-along page. Returns the running host.
Future<ShareHost> startHost({
  required String name,
  required SharedView initial,
  SharedSong? initialSong,
}) =>
    impl.startHost(name: name, initial: initial, initialSong: initialSong);

/// Connect to a discovered (or manually entered) session as a follower.
Future<ShareClient> connectClient(DiscoveredSession session) =>
    impl.connectClient(session);

/// Begin listening for sessions advertised on the local network.
ShareDiscovery startDiscovery() => impl.startDiscovery();

/// A running host: keeps followers in sync with the shared view.
abstract class ShareHost {
  /// The TCP port the WebSocket server is bound to.
  int get wsPort;

  /// LAN addresses others can use to join. These are `http://ip:port` URLs:
  /// opening one in a browser loads the follow-along page; the native app
  /// accepts the same URL in its "join by address" field.
  List<String> get joinUrls;

  /// Live count of connected followers.
  Stream<int> get clientCount;

  /// Push a new shared view to all followers. Pass [song] when the song itself
  /// changed so the browser page can render the new lyrics (omit for scroll-only
  /// updates to keep traffic light).
  void update(SharedView view, {SharedSong? song});

  /// Stop the server and disconnect everyone.
  Future<void> close();
}

/// A follower connection: emits the host's shared view as it changes.
abstract class ShareClient {
  /// The host's session name (available after the hello handshake).
  String get sessionName;

  /// Stream of shared views received from the host.
  Stream<SharedView> get views;

  /// false once the connection drops.
  Stream<bool> get connected;

  Future<void> close();
}

/// Discovery: emits the current list of sessions seen on the network.
abstract class ShareDiscovery {
  Stream<List<DiscoveredSession>> get sessions;
  Future<void> close();
}
