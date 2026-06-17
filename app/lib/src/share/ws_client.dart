// Platform-neutral follower client. Works on every platform because
// web_socket_channel has both a dart:io and a browser implementation. Used by
// both the dart:io transport (mobile/desktop) and the web transport.

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'transport.dart';

class WsShareClient implements ShareClient {
  final WebSocketChannel _channel;
  String _sessionName;

  // Replay the latest view to any new subscriber so a listener that attaches
  // just after connecting still sees the host's current state.
  SharedView? _last;
  late final StreamController<SharedView> _views = StreamController.broadcast(
    onListen: () {
      final l = _last;
      if (l != null) {
        scheduleMicrotask(() {
          if (!_views.isClosed) _views.add(l);
        });
      }
    },
  );
  final _connected = StreamController<bool>.broadcast();

  WsShareClient(this._channel, this._sessionName) {
    _channel.stream.listen(
      (data) {
        final raw = data is String ? data : utf8.decode(data as List<int>);
        final msg = ShareMessage.tryDecode(raw);
        if (msg == null) return;
        if (msg.sessionName != null && msg.sessionName!.isNotEmpty) {
          _sessionName = msg.sessionName!;
        }
        if (msg.type == ShareMessageType.bye) {
          _drop();
          return;
        }
        if (msg.view != null) {
          _last = msg.view;
          if (!_views.isClosed) _views.add(msg.view!);
        }
      },
      onDone: _drop,
      onError: (_) => _drop(),
      cancelOnError: true,
    );
    if (!_connected.isClosed) _connected.add(true);
  }

  void _drop() {
    if (!_connected.isClosed) _connected.add(false);
  }

  @override
  String get sessionName => _sessionName;

  @override
  Stream<SharedView> get views => _views.stream;

  @override
  Stream<bool> get connected => _connected.stream;

  @override
  Future<void> close() async {
    try {
      await _channel.sink.close();
    } catch (_) {}
    if (!_views.isClosed) await _views.close();
    if (!_connected.isClosed) await _connected.close();
  }
}

/// Open a follower connection to [session] (used by every platform).
Future<ShareClient> openWsClient(DiscoveredSession session) async {
  final channel = WebSocketChannel.connect(Uri.parse(session.wsUrl));
  await channel.ready; // throws if unreachable
  return WsShareClient(channel, session.name);
}
