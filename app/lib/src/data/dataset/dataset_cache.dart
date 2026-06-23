// Persistent cache for an over-the-air dataset update. Mobile/desktop store the
// downloaded gzip in the app-support directory; web has no file cache (no-op),
// so the conditional import keeps the web build compiling.
export 'package:indirimbo/src/data/dataset/dataset_cache_stub.dart' if (dart.library.io) 'package:indirimbo/src/data/dataset/dataset_cache_io.dart';
