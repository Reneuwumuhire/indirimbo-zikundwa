import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:indirimbo/src/data/models.dart';
import 'package:indirimbo/src/state/settings.dart';
import 'package:indirimbo/src/core/app_theme.dart';

/// Classic-hymnal lyrics: each stanza is introduced by a small monospace label
/// ("VERSE 1", "CHORUS") above serif body text. Choruses are italic with a thin
/// rust rule.
class LyricsViewer extends ConsumerWidget {
  final Song song;
  final ReaderSettings settings;
  final bool showChords;
  const LyricsViewer({
    super.key,
    required this.song,
    required this.settings,
    this.showChords = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<ReaderPalette>()!;
    final t = ref.watch(stringsProvider);
    final lyricsFont = ref.watch(fontComboProvider).lyrics;
    int verseNo = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stanza in song.stanzas)
          _StanzaBlock(
            stanza: stanza,
            label: stanza.type == StanzaType.chorus
                ? t.refrainLabel
                : t.verseLabel(++verseNo),
            settings: settings,
            lyricsFont: lyricsFont,
            palette: palette,
          ),
      ],
    );
  }
}

/// Breaks a flowing stanza paragraph into hymn lines at clause punctuation
/// (comma, semicolon, colon, period, !, ?, …), keeping the punctuation on the
/// line. The source data has no line breaks, so this restores a printed-hymnal
/// layout where each line ends where the phrase ends.
List<String> verseLines(String text) {
  final t = text.trim();
  if (t.isEmpty) return const [];

  // Break into clauses, keeping each clause's trailing punctuation.
  final clauses = <String>[];
  for (final m in RegExp(r'[^,;:.!?…»]+[,;:.!?…»]*').allMatches(t)) {
    final c = m.group(0)!.trim();
    if (c.isNotEmpty) clauses.add(c);
  }

  // Accumulate clauses and only break a line once it reaches a sensible length,
  // so short clauses ("Paix!", "Dieu,", "waimba,") merge instead of becoming
  // choppy one-word lines. Lines still end at a clause boundary (punctuation).
  const minLen = 24;
  final lines = <String>[];
  var cur = '';
  for (final c in clauses) {
    cur = cur.isEmpty ? c : '$cur $c';
    if (cur.length >= minLen) {
      lines.add(cur);
      cur = '';
    }
  }
  if (cur.isNotEmpty) {
    // Fold a very short trailing remainder into the previous line.
    if (lines.isNotEmpty && cur.length < 12) {
      lines[lines.length - 1] = '${lines.last} $cur';
    } else {
      lines.add(cur);
    }
  }
  return lines.isEmpty ? [t] : lines;
}

class _StanzaBlock extends StatelessWidget {
  final Stanza stanza;
  final String label;
  final ReaderSettings settings;
  final String lyricsFont;
  final ReaderPalette palette;
  const _StanzaBlock({
    required this.stanza,
    required this.label,
    required this.settings,
    required this.lyricsFont,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final isChorus = stanza.type == StanzaType.chorus;
    // Tight line height within a (possibly wrapping) hymn line…
    final lineStyle = TextStyle(
      fontFamily: lyricsFont,
      fontSize: settings.fontSize,
      height: 1.3,
      fontStyle: isChorus ? FontStyle.italic : FontStyle.normal,
      fontWeight: isChorus ? FontWeight.w700 : FontWeight.normal,
      color: isChorus ? palette.chorusText : palette.verseText,
    );
    // …and a clear gap *between* hymn lines, driven by the line-spacing setting.
    final gap = ((settings.lineHeight - 1.0).clamp(0.25, 1.2)) * settings.fontSize;

    // The source stores each stanza as a flowing paragraph (no line breaks), so
    // we break it into hymn lines at clause punctuation — like a printed hymnal.
    final lines = verseLines(stanza.text);
    final lineColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Text(lines[i], style: lineStyle),
        ],
      ],
    );

    final body = isChorus
        ? Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: palette.chorusAccent.withValues(alpha: 0.6), width: 2)),
            ),
            child: lineColumn,
          )
        : lineColumn;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 10.5,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: isChorus ? palette.chorusAccent : palette.muted,
            ),
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }
}
