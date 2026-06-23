// Reader display settings + theme, persisted with SharedPreferences so choices
// survive restarts. Exposed via Riverpod.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:indirimbo/src/data/book_groups.dart';
import 'package:indirimbo/src/core/app_theme.dart';
import 'package:indirimbo/src/core/font_combos.dart';
import 'package:indirimbo/src/core/strings.dart';

/// How the collection ("books") library is laid out.
enum LibraryLayout { grid, list }

/// How the books are ordered in the library.
enum LibrarySort { alpha, alphaDesc, count, original }

/// Reading fonts bundled in assets/fonts (declared in pubspec).
const readerFonts = <String>[
  'Spectral',
  'Gentium Plus',
  'Libre Baskerville',
  'Georgia',
  'Times New Roman',
  'Inter',
];

@immutable
class ReaderSettings {
  final String fontFamily;
  final double fontSize; // logical px
  final double lineHeight; // multiplier
  final AppThemeMode themeMode;
  final AppLanguage language;
  final LibraryLayout libraryLayout;
  final LibrarySort librarySort;

  /// Index into [fontCombos] — the chosen title/lyrics font pairing.
  final int fontCombo;

  /// Global text scale applied to the whole app's UI text (1.0 = default).
  /// Song lyrics are sized independently via [fontSize].
  final double appTextScale;

  /// Font family used for general app (UI) text. One of [readerFonts].
  final String appFont;

  /// Keep the screen awake while reading lyrics (default on).
  final bool keepScreenOn;

  /// Language-group filter for the library; null = show all groups.
  final BookGroup? libraryFilter;

  const ReaderSettings({
    this.fontFamily = 'Spectral',
    this.fontSize = 19,
    this.lineHeight = 1.6,
    this.themeMode = AppThemeMode.normal,
    this.language = AppLanguage.fr,
    this.libraryLayout = LibraryLayout.grid,
    this.librarySort = LibrarySort.alpha,
    this.fontCombo = 0,
    this.appTextScale = 1.0,
    this.appFont = AppFonts.body,
    this.keepScreenOn = true,
    this.libraryFilter,
  });

  ReaderSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    AppThemeMode? themeMode,
    AppLanguage? language,
    LibraryLayout? libraryLayout,
    LibrarySort? librarySort,
    int? fontCombo,
    double? appTextScale,
    String? appFont,
    bool? keepScreenOn,
    // Use a sentinel so null can be set explicitly (= "All").
    Object? libraryFilter = _unset,
  }) =>
      ReaderSettings(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        themeMode: themeMode ?? this.themeMode,
        language: language ?? this.language,
        libraryLayout: libraryLayout ?? this.libraryLayout,
        librarySort: librarySort ?? this.librarySort,
        fontCombo: fontCombo ?? this.fontCombo,
        appTextScale: appTextScale ?? this.appTextScale,
        appFont: appFont ?? this.appFont,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        libraryFilter: libraryFilter == _unset
            ? this.libraryFilter
            : libraryFilter as BookGroup?,
      );
}

const _unset = Object();

final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('override in main()'),
);

final settingsProvider =
    NotifierProvider<SettingsController, ReaderSettings>(SettingsController.new);

class SettingsController extends Notifier<ReaderSettings> {
  static const _kFont = 'reader.font';
  static const _kSize = 'reader.size';
  static const _kLine = 'reader.line';
  static const _kTheme = 'reader.theme';
  static const _kLang = 'reader.lang';
  static const _kLayout = 'reader.layout';
  static const _kSort = 'reader.sort';
  static const _kCombo = 'reader.combo';
  static const _kAppScale = 'app.textScale';
  static const _kAppFont = 'app.font';
  static const _kWake = 'reader.keepScreenOn';
  static const _kFilter = 'reader.filter'; // -1 = all, else BookGroup index

  static const _minScale = 0.85;
  static const _maxScale = 1.5;

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  ReaderSettings build() {
    final p = _prefs;
    final filterIdx = p.getInt(_kFilter) ?? -1;
    return ReaderSettings(
      fontFamily: p.getString(_kFont) ?? 'Spectral',
      fontSize: p.getDouble(_kSize) ?? 19,
      lineHeight: p.getDouble(_kLine) ?? 1.6,
      themeMode: AppThemeMode.values[
          (p.getInt(_kTheme) ?? 0).clamp(0, AppThemeMode.values.length - 1)],
      language: AppLanguage.values[
          (p.getInt(_kLang) ?? 0).clamp(0, AppLanguage.values.length - 1)],
      libraryLayout: LibraryLayout.values[
          (p.getInt(_kLayout) ?? 0).clamp(0, LibraryLayout.values.length - 1)],
      librarySort: LibrarySort.values[
          (p.getInt(_kSort) ?? 0).clamp(0, LibrarySort.values.length - 1)],
      fontCombo: (p.getInt(_kCombo) ?? 0).clamp(0, fontCombos.length - 1),
      appTextScale: (p.getDouble(_kAppScale) ?? 1.0).clamp(_minScale, _maxScale),
      appFont: _validFont(p.getString(_kAppFont)),
      keepScreenOn: p.getBool(_kWake) ?? true,
      libraryFilter: (filterIdx >= 0 && filterIdx < BookGroup.values.length)
          ? BookGroup.values[filterIdx]
          : null,
    );
  }

  void setFont(String f) {
    state = state.copyWith(fontFamily: f);
    _prefs.setString(_kFont, f);
  }

  void setFontSize(double v) {
    final s = v.clamp(14.0, 30.0);
    state = state.copyWith(fontSize: s);
    _prefs.setDouble(_kSize, s);
  }

  void setLineHeight(double v) {
    final s = v.clamp(1.2, 2.2);
    state = state.copyWith(lineHeight: s);
    _prefs.setDouble(_kLine, s);
  }

  void setTheme(AppThemeMode m) {
    state = state.copyWith(themeMode: m);
    _prefs.setInt(_kTheme, m.index);
  }

  void setLanguage(AppLanguage l) {
    state = state.copyWith(language: l);
    _prefs.setInt(_kLang, l.index);
  }

  void setLibraryLayout(LibraryLayout l) {
    state = state.copyWith(libraryLayout: l);
    _prefs.setInt(_kLayout, l.index);
  }

  void setLibrarySort(LibrarySort s) {
    state = state.copyWith(librarySort: s);
    _prefs.setInt(_kSort, s.index);
  }

  /// Set the library language filter; pass null for "All".
  void setLibraryFilter(BookGroup? g) {
    state = state.copyWith(libraryFilter: g);
    _prefs.setInt(_kFilter, g?.index ?? -1);
  }

  void setFontCombo(int i) {
    final v = i.clamp(0, fontCombos.length - 1);
    state = state.copyWith(fontCombo: v);
    _prefs.setInt(_kCombo, v);
  }

  static String _validFont(String? f) =>
      (f != null && readerFonts.contains(f)) ? f : AppFonts.body;

  void setAppTextScale(double v) {
    final s = v.clamp(_minScale, _maxScale);
    state = state.copyWith(appTextScale: s);
    _prefs.setDouble(_kAppScale, s);
  }

  void setAppFont(String f) {
    final v = _validFont(f);
    state = state.copyWith(appFont: v);
    _prefs.setString(_kAppFont, v);
  }

  /// Restore the app-text settings (font + size) to their defaults.
  void resetAppText() {
    state = state.copyWith(appTextScale: 1.0, appFont: AppFonts.body);
    _prefs.setDouble(_kAppScale, 1.0);
    _prefs.setString(_kAppFont, AppFonts.body);
  }

  /// True when the app-text settings are already at their defaults.
  bool get isAppTextDefault =>
      state.appTextScale == 1.0 && state.appFont == AppFonts.body;

  void setKeepScreenOn(bool v) {
    state = state.copyWith(keepScreenOn: v);
    _prefs.setBool(_kWake, v);
  }
}

/// The currently-selected font pairing.
final fontComboProvider = Provider<FontCombo>((ref) {
  final i = ref.watch(settingsProvider.select((s) => s.fontCombo));
  return fontCombos[i.clamp(0, fontCombos.length - 1)];
});

/// Localized strings for the current language choice.
final stringsProvider = Provider<Strings>((ref) {
  final lang = ref.watch(settingsProvider.select((s) => s.language));
  return Strings.of(lang);
});
