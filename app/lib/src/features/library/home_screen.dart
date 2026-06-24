import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:indirimbo/src/data/book_groups.dart';
import 'package:indirimbo/src/data/models.dart';
import 'package:indirimbo/src/state/providers.dart';
import 'package:indirimbo/src/state/settings.dart';
import 'package:indirimbo/src/core/app_theme.dart';
import 'package:indirimbo/src/features/library/collection_screen.dart';
import 'package:indirimbo/src/widgets/collection_cover.dart';
import 'package:indirimbo/src/widgets/collection_list_tile.dart';

typedef _Entry = ({Collection collection, int index});

void _sortEntries(List<_Entry> entries, LibrarySort sort) {
  switch (sort) {
    case LibrarySort.alpha:
      entries.sort((a, b) =>
          a.collection.name.toLowerCase().compareTo(b.collection.name.toLowerCase()));
    case LibrarySort.alphaDesc:
      entries.sort((a, b) =>
          b.collection.name.toLowerCase().compareTo(a.collection.name.toLowerCase()));
    case LibrarySort.count:
      entries.sort((a, b) => b.collection.songCount.compareTo(a.collection.songCount));
    case LibrarySort.original:
      entries.sort((a, b) => a.index.compareTo(b.index));
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext c, Widget page) =>
      Navigator.of(c).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final t = ref.watch(stringsProvider);
    final repo = ref.watch(repositoryProvider).requireValue;
    final collections = repo.collections;
    final layout = ref.watch(settingsProvider.select((s) => s.libraryLayout));
    final filter = ref.watch(settingsProvider.select((s) => s.libraryFilter));
    final sort = ref.watch(settingsProvider.select((s) => s.librarySort));

    final entries = <_Entry>[
      for (var i = 0; i < collections.length; i++)
        if (filter == null || bookGroupOf(collections[i].id) == filter)
          (collection: collections[i], index: i),
    ];
    _sortEntries(entries, sort);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Masthead(t: t, reader: reader, theme: theme)),
            SliverToBoxAdapter(
              child: _Subhead(
                count: entries.length,
                label: t.allBooks.toUpperCase(),
                layout: layout,
                sort: sort,
                t: t,
                onLayout: (l) => ref.read(settingsProvider.notifier).setLibraryLayout(l),
                onSort: (s) => ref.read(settingsProvider.notifier).setLibrarySort(s),
              ),
            ),
            SliverToBoxAdapter(
              child: _FilterChips(
                allLabel: t.all,
                selected: filter,
                onSelect: (g) => ref.read(settingsProvider.notifier).setLibraryFilter(g),
              ),
            ),
            if (layout == LibraryLayout.grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 22,
                    crossAxisSpacing: 18,
                    mainAxisExtent: 246,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _GridItem(
                      entry: entries[i],
                      onTap: () =>
                          _open(context, CollectionScreen(collectionId: entries[i].collection.id)),
                    ),
                    childCount: entries.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                sliver: SliverList.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: reader.hairline),
                  itemBuilder: (_, i) => CollectionListTile(
                    collection: entries[i].collection,
                    index: entries[i].index,
                    onTap: () =>
                        _open(context, CollectionScreen(collectionId: entries[i].collection.id)),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: Text('INDIRIMBO ZIKUNDWA · ${collections.length} ${t.allBooks.toUpperCase()}',
                      style: TextStyle(
                          fontFamily: AppFonts.mono, fontSize: 9, letterSpacing: 1, color: reader.muted)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  final dynamic t;
  final ReaderPalette reader;
  final ThemeData theme;
  const _Masthead({required this.t, required this.reader, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            margin: const EdgeInsets.only(top: 4, right: 14),
            color: theme.colorScheme.primary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Indirimbo Zikundwa',
                    style: theme.textTheme.displaySmall?.copyWith(fontSize: 27, height: 1.05)),
                const SizedBox(height: 4),
                Text(t.splashSub,
                    style: TextStyle(
                        fontFamily: AppFonts.uiBody,
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        color: reader.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Subhead extends StatelessWidget {
  final int count;
  final String label;
  final LibraryLayout layout;
  final LibrarySort sort;
  final dynamic t;
  final ValueChanged<LibraryLayout> onLayout;
  final ValueChanged<LibrarySort> onSort;
  const _Subhead({
    required this.count,
    required this.label,
    required this.layout,
    required this.sort,
    required this.t,
    required this.onLayout,
    required this.onSort,
  });

  String _sortLabel(LibrarySort s) => switch (s) {
        LibrarySort.alpha => t.sortAlpha,
        LibrarySort.alphaDesc => t.sortAlphaDesc,
        LibrarySort.count => t.sortCount,
        LibrarySort.original => t.sortOriginal,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 10, 2),
      child: Row(
        children: [
          Text('$count · $label',
              style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 12,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                  color: reader.muted)),
          const Spacer(),
          PopupMenuButton<LibrarySort>(
            tooltip: t.sortBy,
            initialValue: sort,
            onSelected: onSort,
            color: theme.colorScheme.surface,
            icon: Icon(Icons.sort_rounded, size: 19, color: reader.muted),
            itemBuilder: (_) => [
              for (final s in LibrarySort.values)
                PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Icon(
                          s == sort ? Icons.check_rounded : Icons.check_rounded,
                          size: 16,
                          color: s == sort ? theme.colorScheme.primary : Colors.transparent),
                      const SizedBox(width: 8),
                      Text(_sortLabel(s),
                          style: TextStyle(
                              fontFamily: AppFonts.uiBody,
                              color: theme.colorScheme.onSurface,
                              fontWeight: s == sort ? FontWeight.w700 : FontWeight.w400)),
                    ],
                  ),
                ),
            ],
          ),
          _layoutBtn(theme, reader, Icons.grid_view_rounded, LibraryLayout.grid),
          _layoutBtn(theme, reader, Icons.view_agenda_outlined, LibraryLayout.list),
        ],
      ),
    );
  }

  Widget _layoutBtn(ThemeData theme, ReaderPalette reader, IconData icon, LibraryLayout l) {
    final on = layout == l;
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: () => onLayout(l),
      icon: Icon(icon, size: 18, color: on ? theme.colorScheme.primary : reader.muted.withValues(alpha: 0.6)),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String allLabel;
  final BookGroup? selected;
  final ValueChanged<BookGroup?> onSelect;
  const _FilterChips({required this.allLabel, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final accent = theme.colorScheme.primary;

    Widget chip(String label, bool on, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 13,
                    letterSpacing: 0.8,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                    color: on ? accent : reader.muted,
                  )),
              const SizedBox(height: 6),
              Container(width: 20, height: 2.5, color: on ? accent : Colors.transparent),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      // Grow with the app text scale so the labels never clip.
      height: MediaQuery.textScalerOf(context).scale(40) + 8,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
        children: [
          chip(allLabel, selected == null, () => onSelect(null)),
          for (final g in bookGroupOrder) chip(g.label, selected == g, () => onSelect(g)),
        ],
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  final _Entry entry;
  final VoidCallback onTap;
  const _GridItem({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reader = Theme.of(context).extension<ReaderPalette>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CollectionCover(collection: entry.collection, index: entry.index, onTap: onTap),
        ),
        const SizedBox(height: 8),
        Text(
          bookGroupOf(entry.collection.id).label.toUpperCase(),
          style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: reader.muted),
        ),
      ],
    );
  }
}
