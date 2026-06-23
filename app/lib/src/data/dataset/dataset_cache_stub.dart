// Web stub: no local file cache, so OTA updates are not persisted (the web app
// is always served fresh anyway).
import 'dart:typed_data';

Future<Uint8List?> readCachedDatasetGz() async => null;
Future<void> writeCachedDatasetGz(Uint8List bytes) async {}
Future<void> clearCachedDataset() async {}
