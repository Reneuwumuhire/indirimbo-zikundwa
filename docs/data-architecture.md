# Data, storage, search & updates — current state and SQLite plan

## Where we are now (after this change)

The dataset is **5,482 songs across 17 collections**, ~11 MB as raw JSON.

What ships and how it loads:

- **Bundled compressed**: `assets/data/hymns.json.gz` (~1.7 MB, down from 11 MB).
  Decoded at launch in `dataset_source.dart` with `package:archive` (works on
  mobile **and** web). The raw `assets/data/hymns.json` stays in the repo for
  tooling/tests but is no longer bundled — **~9 MB off the app download**.
- **In-memory model**: `HymnRepository` parses the JSON once into `Song`
  objects + two indexes (`byId`, `bySeries`). Lookups and `songsIn` are O(1)/O(k).
- **Search**: `repository.search()` is a linear scan over every song's
  precomputed lowercased `searchBlob` (AND over space-separated terms,
  title/number hits ranked above lyrics hits). The search box is now
  **debounced (~180 ms)** so the scan runs at most a few times per second.
- **OTA content updates** (`update_service.dart`): on launch the app fetches
  `…/data/version.json`; if the remote `version` beats the bundled/cached one it
  downloads `…/data/hymns.json.gz` into the app-support dir and applies it on the
  next launch (`dataset_cache_io.dart`; web is a no-op). Hosting lives in
  `website/data/` (published to GitHub Pages).
  - To roll out new songs: regenerate `hymns.json.gz`, drop it in
    `website/data/`, bump `version.json` to `2`, publish. No app store release.
  - When you ship the new data *inside* an app build too, bump
    `kBundledDataVersion` in `dataset_source.dart` to match.

## Is SQLite needed?

**Not for correctness or current speed** — in-memory search over 5.5k songs is
a few ms and the corpus fits in RAM. The honest tradeoffs:

| Concern | Today | With SQLite + FTS5 |
| --- | --- | --- |
| App/download size | Solved by gzip (1.7 MB) | Similar (ship a `.db.gz`) |
| RAM footprint | Whole corpus + `searchBlob` held (~25–35 MB) | Only what's queried |
| Cold-start parse | Parse 11 MB JSON each launch (~hundreds of ms) | Open DB file, no parse |
| Search | Linear scan (fine now; scales O(n)) | FTS5 inverted index, ranked |
| Incremental OTA | Whole 1.7 MB re-download per update | Could patch changed rows |

So SQLite is a **scaling / polish** investment, not a fix. It pays off most if
the corpus grows several-fold or we want partial OTA patches.

## Migration plan (when we choose to do it)

The blocker is that the repository API is **synchronous** (`byId`, `songsIn`,
`search` return immediately) and is consumed by every screen. SQLite is async.

Phased, low-risk path:

1. **Build step**: a Dart/CLI script converts `hymns.json` →
   `hymns.db` with tables `collections`, `songs`, and an FTS5 virtual table
   `songs_fts(title, author, lyrics, content=songs)`. Gzip it →
   `assets/data/hymns.db.gz`.
2. **Keep the API shape**. Load the whole DB once and **hydrate the same
   in-memory indexes** we have today (so screens don't change), but back
   `search()` with an FTS5 query instead of the linear scan. This gets FTS
   ranking + fast search with *zero* UI churn and no async ripple.
3. **Only if RAM matters**: make `byId`/`songsIn` lazy DB reads and convert the
   handful of call sites to async (`FutureProvider`/`AsyncValue`). Do this
   screen-by-screen behind the existing `repositoryProvider`.
4. **Incremental OTA** (optional): ship a `manifest` of per-song checksums and
   download only changed rows into the cached DB.

Recommendation: **do step 1–2 next** (big search/RAM win, minimal risk); defer
3–4 until the corpus or update cadence justifies them.

## App-size reduction — what actually moved the needle

Honest finding: **gzip-compressing `hymns.json` did *not* shrink the APK** —
Android APKs already DEFLATE-compress assets, so the 11 MB JSON was already
~1.7 MB inside the APK. (The gzip is still worth keeping: it shrinks the OTA
download and the on-disk cache, and it's the format the cache expects.)

The real APK lever was **fonts**. The release APK is mostly:
`libflutter.so` (~11 MB, fixed), `libapp.so` (~6 MB Dart code), and fonts.
`Merriweather.ttf` alone was **4.4 MB** (a variable font with 2,384 glyphs).

Fix: the whole corpus + UI uses only **173 distinct characters**, so every
bundled font is subset to exactly that set (`fonttools`), and Merriweather is
also instanced to a single static weight (it's only used at regular weight).

- Fonts on disk: **15.3 MB → 2.8 MB**; fonts in APK: **6.9 MB → 1.65 MB**.
- arm64 release APK: **28.1 MB → 21.6 MB** (also `--obfuscate --split-debug-info`).

To regenerate after changing the dataset or fonts: recompute the charset from
`hymns.json` (basic ASCII + corpus chars + smart punctuation), then
`python3 -m fontTools.subset <font> --text-file=charset.txt`. Original
(non-subset) fonts should be re-fetched from source if a glyph is ever missing.
For Play Store, ship an **AAB** (`flutter build appbundle`) so Google also
splits per-device.
