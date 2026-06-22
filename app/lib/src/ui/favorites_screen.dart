import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/favorites.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../state/strings.dart';
import '../theme/app_theme.dart';
import 'widgets/song_tile.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final t = ref.watch(stringsProvider);
    final repo = ref.watch(repositoryProvider).requireValue;
    final favIds = ref.watch(favoritesProvider);
    final songs = <Song>[
      for (final id in favIds)
        if (repo.byId(id) != null) repo.byId(id)!,
    ]..sort((a, b) {
        final c = a.series.compareTo(b.series);
        return c != 0 ? c : a.number.compareTo(b.number);
      });

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(t.navFavorites, style: theme.textTheme.titleLarge?.copyWith(fontSize: 24)),
            ),
            Expanded(
              child: songs.isEmpty
                  ? _empty(context, reader, t)
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: songs.length,
                      separatorBuilder: (_, __) => Divider(
                          indent: 82, endIndent: 18, height: 1, color: reader.hairline),
                      itemBuilder: (_, i) => SongTile(
                          song: songs[i],
                          subtitle: repo.collection(songs[i].series).name),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, ReaderPalette reader, Strings t) {
    final c = reader.muted;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 46, color: c.withValues(alpha: 0.55)),
          const SizedBox(height: 12),
          Text(t.favEmptyTitle,
              style: TextStyle(fontFamily: AppFonts.uiBody, color: c)),
          const SizedBox(height: 4),
          Text(t.favEmptyHint,
              style: TextStyle(fontFamily: AppFonts.uiBody, color: c, fontSize: 13)),
        ],
      ),
    );
  }
}
