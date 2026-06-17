import 'package:flutter_test/flutter_test.dart';
import 'package:indirimbo/src/share/transport.dart';

void main() {
  group('share protocol', () {
    test('view message round-trips', () {
      const v = SharedView(songId: 'A-Foi-12', scroll: 0.42);
      final decoded = ShareMessage.tryDecode(ShareMessage.viewUpdate(v).encode())!;
      expect(decoded.type, ShareMessageType.view);
      expect(decoded.view, v);
    });

    test('hello carries session name + view', () {
      final m = ShareMessage.hello('Room 7', const SharedView(songId: 's1'));
      final d = ShareMessage.tryDecode(m.encode())!;
      expect(d.type, ShareMessageType.hello);
      expect(d.sessionName, 'Room 7');
      expect(d.view!.songId, 's1');
    });

    test('beacon round-trips and rejects foreign payloads', () {
      const b = ShareBeacon(name: 'Indirimbo', wsPort: 4321);
      expect(ShareBeacon.tryDecode(b.encode())!.wsPort, 4321);
      expect(ShareBeacon.tryDecode('{"magic":"other"}'), isNull);
      expect(ShareBeacon.tryDecode('not json'), isNull);
    });
  });

  test('host broadcasts the shared view to a follower over loopback', () async {
    final host = await startHost(name: 'Test', initial: const SharedView(songId: 's1'));
    addTearDown(host.close);

    final client = await connectClient(
      DiscoveredSession(name: 'Test', host: '127.0.0.1', wsPort: host.wsPort),
    );
    addTearDown(client.close);

    final received = <SharedView>[];
    final sub = client.views.listen(received.add);

    // Allow the hello handshake (initial view) to arrive.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    // Host moves to another song + scroll position.
    host.update(const SharedView(songId: 's2', scroll: 0.5));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await sub.cancel();

    expect(received.first.songId, 's1', reason: 'initial view from hello');
    expect(
      received.any((v) => v.songId == 's2' && v.scroll == 0.5),
      isTrue,
      reason: 'follower receives the host update',
    );
  });
}
