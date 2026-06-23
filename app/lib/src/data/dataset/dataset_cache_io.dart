// dart:io cache: store an OTA-downloaded dataset gzip in the app-support dir.
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<File> _cacheFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/hymns.json.gz');
}

Future<Uint8List?> readCachedDatasetGz() async {
  try {
    final f = await _cacheFile();
    if (await f.exists()) return await f.readAsBytes();
  } catch (_) {/* unreadable cache */}
  return null;
}

Future<void> writeCachedDatasetGz(Uint8List bytes) async {
  final f = await _cacheFile();
  await f.writeAsBytes(bytes, flush: true);
}

Future<void> clearCachedDataset() async {
  try {
    final f = await _cacheFile();
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
