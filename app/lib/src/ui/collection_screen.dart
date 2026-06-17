import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/book_groups.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../theme/app_theme.dart';
import 'widgets/song_tile.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  final String collectionId;
  const CollectionScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String _filter = '';
  String? _artist; // selected artist filter, null = all

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final t = ref.watch(stringsProvider);
    final repo = ref.watch(repositoryProvider).requireValue;
    final collection = repo.collection(widget.collectionId);
    final group = bookGroupOf(widget.collectionId);

    // Distinct artists in this collection (drives the optional artist filter).
    final artists = <String>{
      for (final s in repo.songsIn(widget.collectionId))
        if (s.author != null && s.author!.isNotEmpty) s.author!,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    List<Song> songs = _filter.trim().isEmpty
        ? repo.songsIn(widget.collectionId)
        : repo.search(_filter, seriesId: widget.collectionId);
    if (_artist != null) {
      songs = songs.where((s) => s.author == _artist).toList(growable: false);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(collection.name,
                              style: theme.textTheme.titleLarge?.copyWith(fontSize: 22, height: 1.1)),
                          const SizedBox(height: 5),
                          Text(
                            '${group.label.toUpperCase()} · ${group.code} · ${collection.songCount} ${t.songsUnit}',
                            style: TextStyle(
                                fontFamily: AppFonts.mono,
                                fontSize: 10.5,
                                letterSpacing: 1,
                                color: reader.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: SearchBar(
                hintText: t.searchPrompt,
                leading: Icon(Icons.search, color: reader.muted, size: 20),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            // Artist filter (only for books that credit artists, e.g. Impimbano).
            if (artists.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Icon(Icons.mic_external_on_rounded, size: 16, color: reader.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PopupMenuButton<String?>(
                        tooltip: t.allArtists,
                        position: PopupMenuPosition.under,
                        color: theme.colorScheme.surface,
                        onSelected: (v) => setState(() => _artist = v),
                        itemBuilder: (_) => [
                          PopupMenuItem<String?>(
                            value: null,
                            child: _artistItem(theme, t.allArtists, _artist == null),
                          ),
                          for (final a in artists)
                            PopupMenuItem<String?>(
                              value: a,
                              child: _artistItem(theme, a, _artist == a),
                            ),
                        ],
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(_artist ?? t.allArtists,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontFamily: AppFonts.body,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: _artist == null ? reader.muted : theme.colorScheme.primary)),
                            ),
                            Icon(Icons.arrow_drop_down_rounded, color: reader.muted),
                          ],
                        ),
                      ),
                    ),
                    if (_artist != null)
                      TextButton(
                        onPressed: () => setState(() => _artist = null),
                        child: Text(t.allArtists,
                            style: const TextStyle(fontFamily: AppFonts.body, fontSize: 12)),
                      )
                    else
                      Text(t.artistsCount(artists.length),
                          style: TextStyle(
                              fontFamily: AppFonts.mono, fontSize: 10, color: reader.muted)),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            Divider(height: 1, color: reader.hairline),
            Expanded(
              child: songs.isEmpty
                  ? Center(
                      child: Text(t.noResults,
                          style: TextStyle(fontFamily: AppFonts.body, color: reader.muted)))
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: songs.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: reader.hairline),
                      itemBuilder: (_, i) => SongTile(song: songs[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artistItem(ThemeData theme, String label, bool selected) {
    return Row(
      children: [
        Icon(Icons.check_rounded,
            size: 16,
            color: selected ? theme.colorScheme.primary : Colors.transparent),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.body,
                  color: theme.colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
        ),
      ],
    );
  }
}
