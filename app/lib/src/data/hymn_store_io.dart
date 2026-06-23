// SQLite-backed store (mobile/desktop). The corpus lives in a SQLite database
// built once from the bundled/OTA dataset; songs are queried lazily (low memory,
// no 11 MB JSON parse per launch). Search is accent-insensitive substring +
// a fuzzy edit-distance fallback for typo tolerance.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dataset_source.dart';
import 'hymn_store.dart';
import 'models.dart';
import 'search_text.dart';
import 'update_service.dart';

const _songCols =
    'id, series, number, variant, label, title, author, lyrics, stanzas';

Future<HymnStore> openHymnStore(SharedPreferences prefs) async {
  final dir = await getApplicationSupportDirectory();
  final path = '${dir.path}/hymns.db';
  final dataVersion = localDataVersion(prefs);

  var db = sqlite3.open(path);
  if (!_isBuilt(db, dataVersion)) {
    db.close();
    // Rebuild from scratch so a failed/partial build can't linger.
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
    db = sqlite3.open(path);
    await _build(db, prefs, dataVersion);
  }
  return SqliteHymnStore(db);
}

bool _isBuilt(Database db, int dataVersion) {
  try {
    if (db.userVersion != dataVersion) return false;
    final r = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='songs'");
    return r.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<void> _build(
    Database db, SharedPreferences prefs, int dataVersion) async {
  final json = jsonDecode(await loadDatasetJson(prefs)) as Map<String, dynamic>;

  db.execute('''
    PRAGMA journal_mode = WAL;
    CREATE TABLE collections(id TEXT PRIMARY KEY, data TEXT NOT NULL);
    CREATE TABLE songs(
      id TEXT PRIMARY KEY,
      series TEXT NOT NULL,
      number INTEGER NOT NULL,
      variant TEXT,
      label TEXT NOT NULL,
      title TEXT NOT NULL,
      author TEXT,
      lyrics TEXT NOT NULL,
      stanzas TEXT NOT NULL,
      norm TEXT NOT NULL,
      title_norm TEXT NOT NULL
    );
    CREATE INDEX idx_songs_series ON songs(series);
  ''');

  db.execute('BEGIN');
  final cstmt = db.prepare('INSERT INTO collections(id, data) VALUES(?, ?)');
  for (final c in (json['collections'] as List)) {
    final m = c as Map<String, dynamic>;
    cstmt.execute([m['id'], jsonEncode(m)]);
  }
  cstmt.close();

  final sstmt = db.prepare(
      'INSERT INTO songs($_songCols, norm, title_norm) '
      'VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  for (final s in (json['songs'] as List)) {
    final m = s as Map<String, dynamic>;
    final number = m['number'] as int;
    final label = (m['label'] as String?) ?? '$number';
    final title = (m['title'] as String?) ?? '';
    final author = m['author'] as String?;
    final lyrics = (m['lyrics'] as String?) ?? '';
    final norm = foldText('$label $title ${author ?? ''} $lyrics');
    sstmt.execute([
      m['id'], m['series'], number, m['variant'], label, title, author, lyrics,
      jsonEncode(m['stanzas'] ?? const []), norm, tokenize(title).join(' '),
    ]);
  }
  sstmt.close();
  db.execute('COMMIT');
  db.userVersion = dataVersion;
}

class SqliteHymnStore implements HymnStore {
  SqliteHymnStore(this._db) {
    for (final r in _db.select('SELECT data FROM collections')) {
      _collections
          .add(Collection.fromJson(jsonDecode(r['data'] as String)));
    }
    // Small in-memory index for the fuzzy fallback (id + folded title only).
    for (final r in _db.select('SELECT id, series, title_norm FROM songs')) {
      _titleIndex.add((
        id: r['id'] as String,
        series: r['series'] as String,
        titleNorm: r['title_norm'] as String,
      ));
    }
  }

  final Database _db;
  final List<Collection> _collections = [];
  final List<({String id, String series, String titleNorm})> _titleIndex = [];

  @override
  List<Collection> get collections => _collections;

  @override
  Collection collection(String id) =>
      _collections.firstWhere((c) => c.id == id);

  @override
  List<Song> songsIn(String seriesId) => _db
      .select(
          'SELECT $_songCols FROM songs WHERE series = ? '
          'ORDER BY number, variant',
          [seriesId])
      .map(_songFromRow)
      .toList(growable: false);

  @override
  Song? byId(String id) {
    final r = _db.select('SELECT $_songCols FROM songs WHERE id = ?', [id]);
    return r.isEmpty ? null : _songFromRow(r.first);
  }

  @override
  List<Song> search(String query, {String? seriesId}) {
    final terms = tokenize(query);
    if (terms.isEmpty) return const [];

    // Tier 1 — accent-insensitive substring (AND over terms).
    final where = StringBuffer('WHERE ');
    final args = <Object?>[];
    for (var i = 0; i < terms.length; i++) {
      if (i > 0) where.write(' AND ');
      where.write('norm LIKE ?');
      args.add('%${terms[i]}%');
    }
    if (seriesId != null) {
      where.write(' AND series = ?');
      args.add(seriesId);
    }
    final rows = _db.select(
        'SELECT $_songCols, title_norm, label FROM songs $where LIMIT 600', args);

    final exact = <(int, Song)>[];
    final seen = <String>{};
    for (final r in rows) {
      final titleNum = '${(r['label'] as String).toLowerCase()} '
          '${r['title_norm']}';
      final inTitle = terms.every(titleNum.contains);
      exact.add((inTitle ? 0 : 1, _songFromRow(r)));
      seen.add(r['id'] as String);
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
      final scored = <(int, String)>[];
      for (final t in _titleIndex) {
        if (seen.contains(t.id)) continue;
        if (seriesId != null && t.series != seriesId) continue;
        final d = _fuzzyScore(terms, t.titleNorm);
        if (d != null) scored.add((d, t.id));
      }
      scored.sort((a, b) => a.$1.compareTo(b.$1));
      final ids = [for (final e in scored.take(40)) e.$2];
      if (ids.isNotEmpty) {
        final ph = List.filled(ids.length, '?').join(',');
        final byId = {
          for (final r in _db.select(
              'SELECT $_songCols FROM songs WHERE id IN ($ph)', ids))
            r['id'] as String: _songFromRow(r)
        };
        for (final id in ids) {
          final s = byId[id];
          if (s != null) results.add(s);
        }
      }
    }
    return results;
  }

  int? _fuzzyScore(List<String> terms, String titleNorm) {
    final words = titleNorm.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return null;
    var total = 0;
    for (final term in terms) {
      final thr = fuzzyThreshold(term.length);
      var best = thr + 1;
      for (final w in words) {
        final d = editDistance(term, w, max: thr);
        if (d < best) best = d;
        if (best == 0) break;
      }
      if (best > thr) return null;
      total += best;
    }
    return total;
  }

  Song _songFromRow(Row r) => Song(
        id: r['id'] as String,
        series: r['series'] as String,
        number: r['number'] as int,
        variant: r['variant'] as String?,
        label: r['label'] as String,
        title: r['title'] as String,
        author: r['author'] as String?,
        lyrics: r['lyrics'] as String,
        stanzas: (jsonDecode(r['stanzas'] as String) as List)
            .map((e) => Stanza.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  @override
  void dispose() => _db.close();
}
