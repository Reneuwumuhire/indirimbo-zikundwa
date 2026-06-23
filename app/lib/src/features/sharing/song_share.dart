// Share a song as plain text via the OS share sheet (WhatsApp, Messenger, X,
// email, copy, …). This is distinct from "Partage en direct" (the live
// local-network session) — this just exports the lyrics as shareable text.

import 'package:share_plus/share_plus.dart';

import 'package:indirimbo/src/data/models.dart';
import 'package:indirimbo/src/core/strings.dart';

const _appUrl = 'https://indirimbo-zikundwa.github.io/';

/// Build a clean, readable text rendering of a song for sharing.
String songAsText(Song song, String collectionName, Strings t) {
  final b = StringBuffer();
  b.writeln('#${song.label} — ${song.displayTitle}');
  b.writeln(collectionName);
  if (song.author != null && song.author!.isNotEmpty) b.writeln(song.author);
  b.writeln();

  var verse = 0;
  for (final s in song.stanzas) {
    final label = s.type == StanzaType.chorus ? t.refrainLabel : t.verseLabel(++verse);
    b.writeln('[$label]');
    b.writeln(s.text.trim());
    b.writeln();
  }

  b.writeln('— Indirimbo Zikundwa');
  b.write(_appUrl);
  return b.toString();
}

/// Open the native share sheet with the song's text.
Future<void> shareSong(Song song, String collectionName, Strings t) {
  return SharePlus.instance.share(
    ShareParams(
      text: songAsText(song, collectionName, t),
      subject: '#${song.label} — ${song.displayTitle}',
    ),
  );
}
