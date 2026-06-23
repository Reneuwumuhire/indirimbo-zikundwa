// Resolves the hymn dataset JSON, preferring a newer OTA-downloaded copy over
// the bundled asset. The dataset ships gzip-compressed (~1.7 MB vs 11 MB) and is
// decoded here at load — small download, full corpus offline.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indirimbo/src/data/dataset/dataset_cache.dart';

/// Version of the dataset bundled in *this* build. Bump it whenever new data is
/// shipped inside the app; the OTA check compares the remote version against
/// `max(kBundledDataVersion, cachedVersion)`.
const int kBundledDataVersion = 1;

/// SharedPreferences key holding the version of the cached OTA dataset (if any).
const String kDataVersionPrefKey = 'data.version';

const String _bundledAsset = 'assets/data/hymns.json.gz';

/// Returns the dataset JSON text, using an OTA-cached copy when it is newer than
/// the bundled one, else the bundled asset. Never throws for cache problems —
/// it falls back to the bundled data.
Future<String> loadDatasetJson(SharedPreferences prefs) async {
  final cachedVersion = prefs.getInt(kDataVersionPrefKey) ?? 0;
  if (cachedVersion > kBundledDataVersion) {
    final cached = await readCachedDatasetGz();
    if (cached != null) {
      try {
        return _gunzip(cached);
      } catch (_) {/* corrupt cache → fall back to bundled below */}
    }
  }
  final data = await rootBundle.load(_bundledAsset);
  return _gunzip(data.buffer.asUint8List());
}

String _gunzip(Uint8List gz) => utf8.decode(GZipDecoder().decodeBytes(gz));
