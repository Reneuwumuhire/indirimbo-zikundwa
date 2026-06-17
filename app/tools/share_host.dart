// A tiny command-line HOST for the live-share feature, for local testing.
//
// It starts the same WebSocket host the mobile app uses and lets you change the
// shared song so you can watch followers (mobile app, or the web app in a
// browser) mirror it. No Xcode/Android SDK needed — runs on the Dart VM.
//
// Usage (from the app/ directory):
//   dart run tools/share_host.dart           # interactive: n=next, p=prev, <number>=jump, q=quit
//   dart run tools/share_host.dart auto       # auto-advance every 3s (for automated checks)
//
// It prints the ws:// addresses followers can join, and writes the loopback URL
// to /tmp/indirimbo_host.txt for test scripts.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:indirimbo/src/share/transport.dart';

Future<void> main(List<String> args) async {
  final auto = args.contains('auto');

  final raw = await File('assets/data/hymns.json').readAsString();
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final songs = (data['songs'] as List).cast<Map<String, dynamic>>();
  if (songs.isEmpty) {
    stderr.writeln('No songs found in assets/data/hymns.json');
    exit(1);
  }

  // Spread picks across the corpus so titles differ visibly while testing.
  final picks = <int>[
    for (var k = 0; k < 8; k++) (k * songs.length ~/ 8).clamp(0, songs.length - 1)
  ];
  var pi = 0;
  int idx() => picks[pi % picks.length];
  String idAt() => songs[idx()]['id'] as String;
  String titleAt() => (songs[idx()]['title'] as String?) ?? '(untitled)';

  final host = await startHost(name: 'Hôte de test', initial: SharedView(songId: idAt()));

  final loopback = 'ws://127.0.0.1:${host.wsPort}';
  try {
    await File('/tmp/indirimbo_host.txt').writeAsString(loopback);
  } catch (_) {}

  stdout.writeln('── Indirimbo live-share host ──');
  stdout.writeln('Followers can join at:');
  for (final u in host.joinUrls) {
    stdout.writeln('  $u');
  }
  stdout.writeln('  $loopback   (same machine)');
  stdout.writeln('');
  stdout.writeln('Web followers: serve build/web on this Mac, then open');
  stdout.writeln('  http://<this-mac-ip>:8099/?join=${host.joinUrls.isNotEmpty ? host.joinUrls.first : loopback}');
  stdout.writeln('');

  host.clientCount.listen((n) => stdout.writeln('» $n follower(s) connected'));

  void show() => stdout.writeln('Now sharing → ${titleAt()}');
  show();

  if (auto) {
    // Slowly scroll down the current song, then advance to the next one — so a
    // follower visibly scrolls and then changes song.
    double scroll = 0;
    Timer.periodic(const Duration(milliseconds: 500), (_) {
      scroll += 0.12;
      if (scroll >= 1.05) {
        scroll = 0;
        pi++;
        host.update(SharedView(songId: idAt(), scroll: 0));
        show();
      } else {
        host.update(SharedView(songId: idAt(), scroll: scroll.clamp(0.0, 1.0)));
      }
    });
    // Run until killed.
    await Completer<void>().future;
    return;
  }

  stdout.writeln('Commands: [n]ext  [p]rev  <number 0-${songs.length - 1}>  [q]uit');
  stdin.echoMode = false;
  stdin.lineMode = true;
  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final cmd = line.trim();
    if (cmd == 'q') break;
    if (cmd == 'n') {
      pi++;
    } else if (cmd == 'p') {
      pi += picks.length - 1;
    } else {
      final n = int.tryParse(cmd);
      if (n != null && n >= 0 && n < songs.length) {
        host.update(SharedView(songId: songs[n]['id'] as String));
        stdout.writeln('Now sharing → ${(songs[n]['title'] as String?) ?? ''}');
        continue;
      }
    }
    host.update(SharedView(songId: idAt()));
    show();
  }
  await host.close();
}
