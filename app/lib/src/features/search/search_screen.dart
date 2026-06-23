import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:indirimbo/src/data/models.dart';
import 'package:indirimbo/src/state/providers.dart';
import 'package:indirimbo/src/state/settings.dart';
import 'package:indirimbo/src/core/strings.dart';
import 'package:indirimbo/src/core/app_theme.dart';
import 'package:indirimbo/src/widgets/song_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Debounce keystrokes so the full-corpus search runs at most every ~180ms
  // instead of on every character — keeps typing smooth on large books.
  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) ref.read(searchQueryProvider.notifier).state = v;
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final t = ref.watch(stringsProvider);
    final repo = ref.watch(repositoryProvider).requireValue;
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final hasQuery = query.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(t.navSearch, style: theme.textTheme.titleLarge?.copyWith(fontSize: 24)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SearchBar(
                controller: _controller,
                hintText: t.searchHint,
                leading: Icon(Icons.search, color: reader.muted),
                trailing: [
                  if (hasQuery)
                    IconButton(
                      icon: Icon(Icons.close, color: reader.muted),
                      onPressed: _clear,
                    ),
                ],
                onChanged: _onChanged,
              ),
            ),
            if (hasQuery)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.results(results.length),
                      style: TextStyle(
                          fontFamily: AppFonts.uiBody, fontSize: 12.5, color: reader.muted)),
                ),
              ),
            Expanded(
              child: !hasQuery
                  ? _hint(context, reader, t)
                  : results.isEmpty
                      ? _hint(context, reader, t, empty: true)
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 6, bottom: 16),
                          itemCount: results.length,
                          separatorBuilder: (_, __) => Divider(
                              indent: 82, endIndent: 18, height: 1, color: reader.hairline),
                          itemBuilder: (_, i) {
                            final Song s = results[i];
                            return SongTile(
                                song: s, subtitle: repo.collection(s.series).name);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, ReaderPalette reader, Strings t,
      {bool empty = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(empty ? Icons.search_off : Icons.search,
              size: 46, color: reader.muted.withValues(alpha: 0.55)),
          const SizedBox(height: 12),
          Text(empty ? t.noResults : t.searchPrompt,
              style: TextStyle(fontFamily: AppFonts.uiBody, color: reader.muted)),
        ],
      ),
    );
  }
}
