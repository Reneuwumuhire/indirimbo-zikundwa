// Loads the hymn dataset once and answers in-memory queries. The corpus ships
// gzip-compressed and is decoded at load (see dataset_source.dart), preferring
// an OTA-updated copy over the bundled asset when one is cached.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dataset_source.dart';
import 'models.dart';

class HymnRepository {
  HymnRepository._(this.dataset, this._byId, this._bySeries);

  final Dataset dataset;
  final Map<String, Song> _byId;
  final Map<String, List<Song>> _bySeries;

  static Future<HymnRepository> load(SharedPreferences prefs) async {
    final raw = await loadDatasetJson(prefs);
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final collections = (json['collections'] as List<dynamic>)
        .map((e) => Collection.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final songs = (json['songs'] as List<dynamic>)
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    final byId = {for (final s in songs) s.id: s};
    final bySeries = <String, List<Song>>{};
    for (final s in songs) {
      (bySeries[s.series] ??= <Song>[]).add(s);
    }
    for (final list in bySeries.values) {
      list.sort((a, b) {
        final c = a.number.compareTo(b.number);
        return c != 0 ? c : (a.variant ?? '').compareTo(b.variant ?? '');
      });
    }
    return HymnRepository._(
      Dataset(collections: collections, songs: songs),
      byId,
      bySeries,
    );
  }

  List<Collection> get collections => dataset.collections;

  Collection collection(String id) =>
      dataset.collections.firstWhere((c) => c.id == id);

  List<Song> songsIn(String seriesId) => _bySeries[seriesId] ?? const [];

  Song? byId(String id) => _byId[id];

  /// Full-text search across number, title and lyrics. Each space-separated
  /// term must match somewhere in the song (AND semantics). Title/number hits
  /// rank above lyrics-only hits.
  List<Song> search(String query, {String? seriesId}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final terms = q.split(RegExp(r'\s+'));
    final pool = seriesId == null ? dataset.songs : songsIn(seriesId);

    final scored = <(int, Song)>[];
    for (final s in pool) {
      if (!terms.every((t) => s.searchBlob.contains(t))) continue;
      final inTitleOrNum =
          terms.every((t) => s.label.toLowerCase().contains(t) || s.title.toLowerCase().contains(t));
      scored.add((inTitleOrNum ? 0 : 1, s));
    }
    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      final cc = a.$2.series.compareTo(b.$2.series);
      return cc != 0 ? cc : a.$2.number.compareTo(b.$2.number);
    });
    return scored.map((e) => e.$2).toList(growable: false);
  }
}
