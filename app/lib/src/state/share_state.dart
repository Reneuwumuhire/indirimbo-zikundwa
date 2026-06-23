// Riverpod state for the "SharePlay"-style live song sharing.
//
// One device hosts (broadcasts what it is viewing); others follow (mirror it).
// The transport itself lives in lib/src/share; this layer manages the session
// lifecycle and exposes it to the UI.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:indirimbo/src/data/models.dart';
import 'package:indirimbo/src/features/sharing/transport.dart';
import 'package:indirimbo/src/state/providers.dart';

enum ShareRole { none, host, follower }

@immutable
class ShareSession {
  final ShareRole role;

  /// Host: number of connected followers.
  final int followers;

  /// Follower: name of the session being followed.
  final String? sessionName;

  /// Follower: whether the connection is still alive.
  final bool connected;

  /// Follower: the latest view received from the host.
  final SharedView? followedView;

  /// Host: addresses (ws URLs) others can use to join.
  final List<String> joinUrls;

  /// Non-null when the last action failed (shown to the user once).
  final String? error;

  const ShareSession({
    this.role = ShareRole.none,
    this.followers = 0,
    this.sessionName,
    this.connected = false,
    this.followedView,
    this.joinUrls = const [],
    this.error,
  });

  bool get isHosting => role == ShareRole.host;
  bool get isFollowing => role == ShareRole.follower;

  ShareSession copyWith({
    ShareRole? role,
    int? followers,
    String? sessionName,
    bool? connected,
    SharedView? followedView,
    List<String>? joinUrls,
    String? error,
  }) =>
      ShareSession(
        role: role ?? this.role,
        followers: followers ?? this.followers,
        sessionName: sessionName ?? this.sessionName,
        connected: connected ?? this.connected,
        followedView: followedView ?? this.followedView,
        joinUrls: joinUrls ?? this.joinUrls,
        error: error,
      );
}

final shareSupportedProvider = Provider<bool>((_) => isShareSupported);
final canHostProvider = Provider<bool>((_) => canHostSessions);
final canJoinProvider = Provider<bool>((_) => canJoinSessions);

/// Streams the sessions discovered on the local network (only while watched).
final discoveryProvider = StreamProvider.autoDispose<List<DiscoveredSession>>((ref) {
  if (!isShareSupported) return Stream.value(const []);
  final discovery = startDiscovery();
  ref.onDispose(discovery.close);
  return discovery.sessions;
});

/// Always-on discovery used to surface the "session nearby" banner while the
/// app is open (kept alive for the app lifetime). Empty on web (no UDP).
final nearbySessionsProvider = StreamProvider<List<DiscoveredSession>>((ref) {
  if (!canHostSessions) return Stream.value(const []); // web/desktop w/o UDP
  final discovery = startDiscovery();
  ref.onDispose(discovery.close);
  return discovery.sessions;
});

/// Join targets the user has dismissed (so the banner doesn't nag).
final dismissedNearbyProvider = StateProvider<Set<String>>((_) => {});

final shareControllerProvider =
    NotifierProvider<ShareController, ShareSession>(ShareController.new);

class ShareController extends Notifier<ShareSession> {
  ShareHost? _host;
  ShareClient? _client;
  final _subs = <StreamSubscription>[];

  /// The song currently broadcast to followers — so we only resend full lyrics
  /// when the song actually changes (scroll updates stay light).
  String? _hostedSongId;

  @override
  ShareSession build() {
    ref.onDispose(_teardown);
    return const ShareSession();
  }

  /// Resolve a song's full content from the bundled hymnal so the browser
  /// follow-along page can render it. Null if the repository isn't ready.
  SharedSong? _songFor(String songId) {
    final repo = ref.read(repositoryProvider).valueOrNull;
    final song = repo?.byId(songId);
    if (repo == null || song == null) return null;
    return SharedSong(
      songId: song.id,
      label: song.label,
      title: song.displayTitle,
      collectionName: repo.collection(song.series).name,
      author: song.author,
      stanzas: [
        for (final s in song.stanzas)
          SharedStanza(chorus: s.type == StanzaType.chorus, text: s.text),
      ],
    );
  }

  /// Begin hosting; followers will mirror [initial] until [updateHostView].
  Future<void> startHosting(SharedView initial, {required String name}) async {
    await _teardown();
    try {
      final initialSong = _songFor(initial.songId);
      _hostedSongId = initialSong != null ? initial.songId : null;
      final host = await startHost(name: name, initial: initial, initialSong: initialSong);
      _host = host;
      _subs.add(host.clientCount.listen((n) {
        state = state.copyWith(followers: n);
      }));
      state = ShareSession(
        role: ShareRole.host,
        followers: 0,
        joinUrls: host.joinUrls,
      );
    } catch (e) {
      state = ShareSession(error: 'Impossible de démarrer le partage : $e');
    }
  }

  /// Host: push the currently-viewed song / scroll to followers. Full lyrics are
  /// attached only when the song changes (browser followers need them); pure
  /// scroll updates send just the view.
  void updateHostView(SharedView view) {
    final host = _host;
    if (host == null) return;
    if (view.songId != _hostedSongId) {
      final song = _songFor(view.songId);
      if (song != null) _hostedSongId = view.songId;
      host.update(view, song: song);
    } else {
      host.update(view);
    }
  }

  /// Join a session entered manually (host:port or ws:// URL).
  Future<void> joinByAddress(String address) async {
    final session = DiscoveredSession.tryParse(address);
    if (session == null) {
      state = const ShareSession(error: 'Adresse invalide');
      return;
    }
    await joinSession(session);
  }

  /// Join a discovered session as a follower.
  Future<void> joinSession(DiscoveredSession session) async {
    await _teardown();
    try {
      final client = await connectClient(session);
      _client = client;
      _subs.add(client.views.listen((v) {
        state = state.copyWith(followedView: v, connected: true);
      }));
      _subs.add(client.connected.listen((alive) {
        state = state.copyWith(connected: alive);
      }));
      state = ShareSession(
        role: ShareRole.follower,
        sessionName: client.sessionName,
        connected: true,
      );
    } catch (e) {
      state = ShareSession(error: 'Connexion impossible : $e');
    }
  }

  /// Leave the current session (host or follower) and reset.
  Future<void> leave() async {
    await _teardown();
    state = const ShareSession();
  }

  Future<void> _teardown() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _host?.close();
    await _client?.close();
    _host = null;
    _client = null;
    _hostedSongId = null;
  }
}
