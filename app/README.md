# Indirimbo Zikundwa — Flutter app

The Flutter application for **Indirimbo Zikundwa**, an offline-first reader for
Christian hymns (Kirundi · Kinyarwanda · Swahili · French). Songs come from
various public-domain hymnals; the app is an independent, offline reader and is
not affiliated with any organization.

> Full project overview, screenshots and store assets are in the
> [repository README](../README.md).

## Run

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get
flutter run                 # connected device / simulator
flutter run -d chrome       # in the browser
flutter test                # run the test suite
flutter analyze             # lint
```

## Build

```bash
flutter build apk --release           # Android APK
flutter build appbundle --release     # Android App Bundle (Play upload)
flutter build ipa --release           # iOS (needs Xcode + Apple signing)
flutter build web --release           # Web (PWA)
```

- **App id:** `bi.indirimbo.indirimbo` · **Name:** “Indirimbo Zikundwa” ·
  **Version:** `1.0.0+1` (bump `version:` in `pubspec.yaml` per release).
- **Icons:** `dart run flutter_launcher_icons` (config in `pubspec.yaml`).

## Architecture

State management is **Riverpod**; settings/favorites persist via
**shared_preferences**. The hymn corpus is a bundled JSON asset
(`assets/data/hymns.json`) loaded once and searched in memory.

```
lib/
  main.dart                  app entry; ProviderScope + MaterialApp(theme by mode)
  src/data/
    models.dart              Song/Collection/Stanza; displayTitle normalization
    hymn_repository.dart      loads hymns.json, in-memory search
    book_groups.dart          language grouping (Kirundi/Kinyarwanda/Swahili/French/Combiné)
  src/state/
    settings.dart             ReaderSettings (theme, fonts, layout, sort, keepScreenOn…) + providers
    favorites.dart            favorites set (persisted)
    providers.dart            repository, search, selected tab, immersive flag
    strings.dart              lightweight FR/EN localization
    share_state.dart          live-share session + nearby-session discovery
  src/theme/
    app_theme.dart            "Cantica" parchment themes + reader palette + book colours
    font_combos.dart          selectable title/lyrics font pairings
  src/share/                  local-network live-share transport
    transport.dart            platform-agnostic API (conditional import)
    transport_io.dart          dart:io WebSocket host + UDP discovery (mobile/desktop)
    transport_web.dart         web: join-only (no host/discovery)
    ws_client.dart             shared follower client
  src/ui/
    root_shell.dart           bottom nav, follower overlay, nearby banner
    home_screen.dart          library (cover grid/list, filter, sort)
    collection_screen.dart    a hymnal's song list
    reader_screen.dart        reader: double-tap fullscreen, pinch-zoom, prev/next, share
    follower_screen.dart      live "EN DIRECT" follower view
    settings_screen.dart      settings (language, layout, fonts, theme, keep-screen-on, about)
    share_sheet.dart          host/join live share
    about_sheet.dart          app info
    widgets/                  collection_cover, collection_list_tile, song_tile, lyrics_viewer, reader_controls
tools/share_host.dart        CLI live-share host (testing without a device)
test/                        dataset / title / verse-line / share-transport tests
```

## Assets

Fonts (bundled, offline) live in `assets/fonts/` and are declared in
`pubspec.yaml`: Playfair Display + Spectral + Space Mono (core), plus the
selectable pairing families (Montserrat, Lora, Oswald, Merriweather, Syne, Plus
Jakarta Sans, Cormorant Garamond, Source Sans 3, Archivo Black, Roboto Mono,
Fraunces, DM Sans, Space Grotesk, Arimo). Regenerate the dataset with
`node ../tools/scrape.mjs`.

## Live share — local test (no device needed)

```bash
flutter build web --release
cd build/web && python3 -m http.server 8099 --bind 0.0.0.0   # serve on LAN
# another terminal:
dart run tools/share_host.dart auto                          # CLI host
```
Open `http://<mac-ip>:8099/?join=ws://<mac-ip>:<port>` on a phone to follow.
