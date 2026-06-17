import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/favorites.dart';
import '../../state/settings.dart';
import '../../theme/app_theme.dart';
import '../reader_screen.dart';

/// A song row in the classic-hymnal style: a rust monospace number, a serif
/// title, and an optional monospace meta line (author / collection).
class SongTile extends ConsumerWidget {
  final Song song;
  final String? subtitle;
  const SongTile({super.key, required this.song, this.subtitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final combo = ref.watch(fontComboProvider);
    final isFav = ref.watch(favoritesProvider).contains(song.id);
    final meta = subtitle ?? song.author;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReaderScreen(songId: song.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  song.label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontWeight: FontWeight.w700,
                    fontSize: song.label.length > 3 ? 11.5 : 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: combo.title,
                      fontWeight: combo.titleWeight,
                      fontStyle: combo.titleItalic ? FontStyle.italic : FontStyle.normal,
                      fontSize: 16.5,
                      height: 1.2,
                      color: reader.verseText,
                    ),
                  ),
                  if (meta != null && meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 10.5,
                          letterSpacing: 0.2,
                          color: reader.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (isFav)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.favorite, size: 14, color: theme.colorScheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}
