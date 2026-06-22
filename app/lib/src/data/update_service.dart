// Over-the-air content updates: refresh the hymn dataset without shipping a new
// app build. On launch the app checks a small version manifest; if a newer
// dataset is published it downloads + caches the gzip, applied on next load.
//
// Hosting: the published site folder (GitHub Pages). Add two files under
//   website/data/version.json     -> {"version": 2}
//   website/data/hymns.json.gz    -> the new compressed dataset
// and bump the version number to roll out an update.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'dataset_cache.dart';
import 'dataset_source.dart';

const String kDataUpdateBaseUrl =
    'https://reneuwumuhire.github.io/indirimbo-zikundwa/data';

/// The locally-effective dataset version (cached OTA version if it beats the
/// bundled one, else the bundled version).
int localDataVersion(SharedPreferences prefs) {
  final cached = prefs.getInt(kDataVersionPrefKey) ?? 0;
  return cached > kBundledDataVersion ? cached : kBundledDataVersion;
}

/// Checks the remote manifest and downloads a newer dataset if available.
/// Returns true when a new version was downloaded and cached (applied on next
/// launch). Silent on any network/parse error — never throws.
Future<bool> checkForDatasetUpdate(
  SharedPreferences prefs, {
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  try {
    final vres = await c
        .get(Uri.parse('$kDataUpdateBaseUrl/version.json'))
        .timeout(const Duration(seconds: 8));
    if (vres.statusCode != 200) return false;

    final manifest = jsonDecode(vres.body) as Map<String, dynamic>;
    final remote = (manifest['version'] as num?)?.toInt() ?? 0;
    if (remote <= localDataVersion(prefs)) return false;

    final url =
        (manifest['url'] as String?) ?? '$kDataUpdateBaseUrl/hymns.json.gz';
    final dres =
        await c.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (dres.statusCode != 200 || dres.bodyBytes.isEmpty) return false;

    await writeCachedDatasetGz(dres.bodyBytes);
    await prefs.setInt(kDataVersionPrefKey, remote);
    return true;
  } catch (_) {
    return false;
  } finally {
    if (client == null) c.close();
  }
}
