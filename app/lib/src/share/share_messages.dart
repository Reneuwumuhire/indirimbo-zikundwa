// Wire protocol for "SharePlay"-style live song sharing on a local network.
//
// A host broadcasts what it is currently viewing (which song / variant and how
// far it is scrolled); followers mirror it. Messages are small JSON objects sent
// over a WebSocket. Everything here is pure Dart so it can be unit-tested and
// compiled for every platform (including web).

import 'dart:convert';

/// The fixed UDP port hosts beacon on and followers listen on for discovery.
const int kDiscoveryPort = 48999;

/// Magic marker so we ignore unrelated datagrams on the discovery port.
const String kBeaconMagic = 'INDIRIMBO_SHARE_V1';

/// The "view" a host is sharing: the song being read and the scroll position.
class SharedView {
  final String songId;

  /// 0.0–1.0 fraction of the reader scrolled (layouts differ between devices,
  /// so we sync a fraction rather than an absolute pixel offset).
  final double scroll;

  const SharedView({required this.songId, this.scroll = 0});

  SharedView copyWith({String? songId, double? scroll}) =>
      SharedView(songId: songId ?? this.songId, scroll: scroll ?? this.scroll);

  Map<String, dynamic> toJson() => {'songId': songId, 'scroll': scroll};

  factory SharedView.fromJson(Map<String, dynamic> j) => SharedView(
        songId: j['songId'] as String,
        scroll: (j['scroll'] as num?)?.toDouble() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is SharedView && other.songId == songId && other.scroll == scroll;

  @override
  int get hashCode => Object.hash(songId, scroll);
}

enum ShareMessageType { hello, view, bye }

/// A single message exchanged over the socket.
class ShareMessage {
  final ShareMessageType type;

  /// Present for [ShareMessageType.view] / hello.
  final SharedView? view;

  /// Human-readable session name (sent in hello).
  final String? sessionName;

  const ShareMessage({required this.type, this.view, this.sessionName});

  factory ShareMessage.hello(String sessionName, SharedView? view) =>
      ShareMessage(type: ShareMessageType.hello, sessionName: sessionName, view: view);
  factory ShareMessage.viewUpdate(SharedView view) =>
      ShareMessage(type: ShareMessageType.view, view: view);
  factory ShareMessage.bye() => const ShareMessage(type: ShareMessageType.bye);

  String encode() => jsonEncode({
        't': type.name,
        if (sessionName != null) 'name': sessionName,
        if (view != null) 'view': view!.toJson(),
      });

  static ShareMessage? tryDecode(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final type = ShareMessageType.values.firstWhere(
        (t) => t.name == j['t'],
        orElse: () => ShareMessageType.view,
      );
      final v = j['view'] as Map<String, dynamic>?;
      return ShareMessage(
        type: type,
        view: v == null ? null : SharedView.fromJson(v),
        sessionName: j['name'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// A discovery beacon payload broadcast by a host over UDP.
class ShareBeacon {
  final String name; // session display name
  final int wsPort; // TCP port the host's WebSocket server listens on

  const ShareBeacon({required this.name, required this.wsPort});

  String encode() =>
      jsonEncode({'magic': kBeaconMagic, 'name': name, 'wsPort': wsPort});

  static ShareBeacon? tryDecode(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['magic'] != kBeaconMagic) return null;
      return ShareBeacon(name: j['name'] as String, wsPort: j['wsPort'] as int);
    } catch (_) {
      return null;
    }
  }
}

/// A session a follower can join, surfaced by discovery.
class DiscoveredSession {
  final String name;
  final String host; // IP address
  final int wsPort;

  const DiscoveredSession({required this.name, required this.host, required this.wsPort});

  String get wsUrl => 'ws://$host:$wsPort/';

  /// Parse a user-entered address into a session. Accepts `ws://host:port`,
  /// `http://host:port`, or bare `host:port`. Returns null if unparseable.
  static DiscoveredSession? tryParse(String input, {String name = 'Session'}) {
    var s = input.trim();
    if (s.isEmpty) return null;
    if (!s.contains('://')) s = 'ws://$s';
    try {
      final uri = Uri.parse(s);
      if (uri.host.isEmpty || uri.port == 0) return null;
      return DiscoveredSession(name: name, host: uri.host, wsPort: uri.port);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DiscoveredSession && other.host == host && other.wsPort == wsPort;

  @override
  int get hashCode => Object.hash(host, wsPort);
}
