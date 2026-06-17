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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final t = ref.watch(stringsProvider);
    final repo = ref.watch(repositoryProvider).requireValue;
    final collection = repo.collection(widget.collectionId);
    final group = bookGroupOf(widget.collectionId);
    final List<Song> songs = _filter.trim().isEmpty
        ? repo.songsIn(widget.collectionId)
        : repo.search(_filter, seriesId: widget.collectionId);

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
}
