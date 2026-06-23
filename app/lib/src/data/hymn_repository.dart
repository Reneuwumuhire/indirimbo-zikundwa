// Public data API for the app. Delegates to a [HymnStore] — SQLite on
// mobile/desktop, in-memory on web — so callers stay storage-agnostic and
// synchronous.

import 'package:shared_preferences/shared_preferences.dart';

import 'package:indirimbo/src/data/store/hymn_store.dart';
import 'package:indirimbo/src/data/models.dart';

class HymnRepository {
  HymnRepository(this._store);

  final HymnStore _store;

  static Future<HymnRepository> load(SharedPreferences prefs) async =>
      HymnRepository(await openHymnStore(prefs));

  List<Collection> get collections => _store.collections;

  Collection collection(String id) => _store.collection(id);

  List<Song> songsIn(String seriesId) => _store.songsIn(seriesId);

  Song? byId(String id) => _store.byId(id);

  /// Forgiving full-text search across number, title and lyrics: accent- and
  /// case-insensitive, with a fuzzy fallback so small typos still match.
  List<Song> search(String query, {String? seriesId}) =>
      _store.search(query, seriesId: seriesId);
}
