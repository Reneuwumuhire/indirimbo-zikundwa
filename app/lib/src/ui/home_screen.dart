import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/book_groups.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../theme/app_theme.dart';
import 'collection_screen.dart';
import 'widgets/collection_cover.dart';
import 'widgets/collection_list_tile.dart';

typedef _Entry = ({Collection collection, int index});

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

    final entries = <_Entry>[
      for (var i = 0; i < collections.length; i++)
        if (filter == null || bookGroupOf(collections[i].id) == filter)
          (collection: collections[i], index: i),
    ];

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
                onLayout: (l) => ref.read(settingsProvider.notifier).setLibraryLayout(l),
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
                        fontFamily: AppFonts.body,
                        fontStyle: FontStyle.italic,
                        fontSize: 14.5,
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
  final ValueChanged<LibraryLayout> onLayout;
  const _Subhead(
      {required this.count, required this.label, required this.layout, required this.onLayout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 2),
      child: Row(
        children: [
          Text('$count · $label',
              style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: reader.muted)),
          const Spacer(),
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
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    color: on ? accent : reader.muted,
                  )),
              const SizedBox(height: 5),
              Container(width: 16, height: 2, color: on ? accent : Colors.transparent),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
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
              fontFamily: AppFonts.mono, fontSize: 9.5, letterSpacing: 1, color: reader.muted),
        ),
      ],
    );
  }
}
