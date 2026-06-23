// The data store behind [HymnRepository]. On mobile/desktop it is backed by
// SQLite (lazy queries + typo-tolerant search); on web it falls back to an
// in-memory store loaded from the bundled JSON. The conditional import keeps
// the web build free of the dart:ffi-based sqlite3 dependency.

import 'package:shared_preferences/shared_preferences.dart';

import 'hymn_store_web.dart' if (dart.library.io) 'hymn_store_io.dart' as impl;
import 'models.dart';

abstract class HymnStore {
  List<Collection> get collections;
  Collection collection(String id);
  List<Song> songsIn(String seriesId);
  Song? byId(String id);

  /// Forgiving full-text search: accent-insensitive substring matching plus a
  /// fuzzy (edit-distance) fallback so small typos still find the right song.
  List<Song> search(String query, {String? seriesId});

  void dispose() {}
}

Future<HymnStore> openHymnStore(SharedPreferences prefs) =>
    impl.openHymnStore(prefs);
