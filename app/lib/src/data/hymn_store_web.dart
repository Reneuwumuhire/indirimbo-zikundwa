// In-memory store (web fallback). Loads the whole corpus from the bundled JSON
// and answers queries from memory. Search is accent-insensitive substring + a
// fuzzy edit-distance fallback (shared with the SQLite store).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dataset_source.dart';
import 'hymn_store.dart';
import 'models.dart';
import 'search_text.dart';

Future<HymnStore> openHymnStore(SharedPreferences prefs) async {
  final json = jsonDecode(await loadDatasetJson(prefs)) as Map<String, dynamic>;
  final collections = (json['collections'] as List<dynamic>)
      .map((e) => Collection.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
  final songs = (json['songs'] as List<dynamic>)
      .map((e) => Song.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
  return MemoryHymnStore(collections, songs);
}

class MemoryHymnStore implements HymnStore {
  MemoryHymnStore(this._collections, List<Song> songs)
      : _byId = {for (final s in songs) s.id: s} {
    for (final s in songs) {
      (_bySeries[s.series] ??= <Song>[]).add(s);
      _folded[s.id] = foldText(s.searchBlob);
    }
    for (final list in _bySeries.values) {
      list.sort((a, b) {
        final c = a.number.compareTo(b.number);
        return c != 0 ? c : (a.variant ?? '').compareTo(b.variant ?? '');
      });
    }
  }

  final List<Collection> _collections;
  final Map<String, Song> _byId;
  final Map<String, List<Song>> _bySeries = {};
  final Map<String, String> _folded = {};

  @override
  List<Collection> get collections => _collections;

  @override
  Collection collection(String id) => _collections.firstWhere((c) => c.id == id);

  @override
  List<Song> songsIn(String seriesId) => _bySeries[seriesId] ?? const [];

  @override
  Song? byId(String id) => _byId[id];

  @override
  List<Song> search(String query, {String? seriesId}) {
    final terms = tokenize(query);
    if (terms.isEmpty) return const [];
    final pool = seriesId == null
        ? _byId.values.toList(growable: false)
        : songsIn(seriesId);

    // Tier 1 — accent-insensitive substring (AND over terms). Title/number hits
    // rank above lyrics-only hits.
    final exact = <(int, Song)>[];
    final seen = <String>{};
    for (final s in pool) {
      final blob = _folded[s.id] ?? foldText(s.searchBlob);
      if (!terms.every(blob.contains)) continue;
      final titleNum = '${s.label} ${foldText(s.title)}';
      final inTitle = terms.every(titleNum.contains);
      exact.add((inTitle ? 0 : 1, s));
      seen.add(s.id);
    }
    exact.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      final cc = a.$2.series.compareTo(b.$2.series);
      return cc != 0 ? cc : a.$2.number.compareTo(b.$2.number);
    });
    final results = [for (final e in exact) e.$2];

    // Tier 2 — fuzzy fallback when exact matches are thin (catches typos).
    if (results.length < 8) {
      final scored = <(int, Song)>[];
      for (final s in pool) {
        if (seen.contains(s.id)) continue;
        final dist = _fuzzyScore(terms, s);
        if (dist != null) scored.add((dist, s));
      }
      scored.sort((a, b) => a.$1.compareTo(b.$1));
      results.addAll(scored.map((e) => e.$2));
    }
    return results;
  }

  /// Total edit distance if every query term fuzzily matches a title word,
  /// else null (not a fuzzy match).
  int? _fuzzyScore(List<String> terms, Song s) {
    final words = tokenize(s.title);
    if (words.isEmpty) return null;
    var total = 0;
    for (final t in terms) {
      final thr = fuzzyThreshold(t.length);
      var best = thr + 1;
      for (final w in words) {
        final d = editDistance(t, w, max: thr);
        if (d < best) best = d;
        if (best == 0) break;
      }
      if (best > thr) return null;
      total += best;
    }
    return total;
  }

  @override
  void dispose() {}
}
