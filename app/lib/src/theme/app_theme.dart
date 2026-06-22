// "Cantica" theming — a warm, classic printed-hymnal aesthetic.
//
// Parchment/cream paper, high-contrast serif display (Playfair Display), a
// readable book serif for reading (Spectral), and a typewriter monospace
// (Space Mono) for small-caps labels, numbers and metadata. A single rust
// accent. Book covers are solid single colours with a darker spine.

import 'package:flutter/material.dart';

enum AppThemeMode { normal, sepia, dark }

extension AppThemeModeX on AppThemeMode {
  String get label => switch (this) {
        AppThemeMode.normal => 'Clair',
        AppThemeMode.sepia => 'Sépia',
        AppThemeMode.dark => 'Sombre',
      };
  IconData get icon => switch (this) {
        AppThemeMode.normal => Icons.wb_sunny_outlined,
        AppThemeMode.sepia => Icons.local_cafe_outlined,
        AppThemeMode.dark => Icons.nightlight_outlined,
      };
}

class AppFonts {
  static const heading = 'Playfair Display'; // display titles
  static const body = 'Spectral'; // default reading + UI serif
  static const mono = 'Space Mono'; // labels, numbers, metadata

  /// The user-selected app (UI) body font. Defaults to [body]; kept in sync
  /// with the `appFont` setting in main() so inline `AppFonts.uiBody` styles
  /// across the UI follow the user's choice. (Song lyrics use the font combo.)
  static String uiBody = body;
}

/// Colours used by the reader and lists beyond the base ColorScheme.
class ReaderPalette extends ThemeExtension<ReaderPalette> {
  final Color page;
  final Color verseText;
  final Color chorusText;
  final Color chorusAccent;
  final Color verseNumber;
  final Color muted;
  final Color hairline;

  const ReaderPalette({
    required this.page,
    required this.verseText,
    required this.chorusText,
    required this.chorusAccent,
    required this.verseNumber,
    required this.muted,
    required this.hairline,
  });

  @override
  ReaderPalette copyWith({
    Color? page,
    Color? verseText,
    Color? chorusText,
    Color? chorusAccent,
    Color? verseNumber,
    Color? muted,
    Color? hairline,
  }) =>
      ReaderPalette(
        page: page ?? this.page,
        verseText: verseText ?? this.verseText,
        chorusText: chorusText ?? this.chorusText,
        chorusAccent: chorusAccent ?? this.chorusAccent,
        verseNumber: verseNumber ?? this.verseNumber,
        muted: muted ?? this.muted,
        hairline: hairline ?? this.hairline,
      );

  @override
  ReaderPalette lerp(ReaderPalette? o, double t) {
    if (o == null) return this;
    return ReaderPalette(
      page: Color.lerp(page, o.page, t)!,
      verseText: Color.lerp(verseText, o.verseText, t)!,
      chorusText: Color.lerp(chorusText, o.chorusText, t)!,
      chorusAccent: Color.lerp(chorusAccent, o.chorusAccent, t)!,
      verseNumber: Color.lerp(verseNumber, o.verseNumber, t)!,
      muted: Color.lerp(muted, o.muted, t)!,
      hairline: Color.lerp(hairline, o.hairline, t)!,
    );
  }
}

class AppTheme {
  static const rust = Color(0xFF9E4A2C);
  static const rustDeep = Color(0xFF7E3A22);

  /// Accent gradient (used for the live-share follower header).
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [rust, rustDeep],
  );

  /// Solid book-cover colours (deep, muted, library-spine palette). One colour
  /// per collection, indexed deterministically.
  static const bookColors = <Color>[
    Color(0xFF2B3A57), // navy
    Color(0xFF3C2A1E), // espresso
    Color(0xFF2E4A35), // forest
    Color(0xFF4C3A52), // plum
    Color(0xFF1F3A43), // deep teal
    Color(0xFF5A2E1E), // sienna
    Color(0xFF572433), // maroon
    Color(0xFF33445C), // slate
    Color(0xFF454A2B), // olive
    Color(0xFF3E2740), // aubergine
    Color(0xFF243250), // ink
    Color(0xFF43301F), // cocoa
  ];

  static Color bookColorFor(int i) => bookColors[i % bookColors.length];

  /// A darker shade for the book spine.
  static Color spineOf(Color c) => Color.alphaBlend(Colors.black.withValues(alpha: 0.26), c);

  static ThemeData of(AppThemeMode mode, {String uiFont = AppFonts.body}) =>
      switch (mode) {
        AppThemeMode.normal => _normal(uiFont),
        AppThemeMode.sepia => _sepia(uiFont),
        AppThemeMode.dark => _dark(uiFont),
      };

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color onSurface,
    required Color heading,
    required Color accent,
    required ReaderPalette reader,
    String uiFont = AppFonts.body,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: onSurface,
    );

    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    final textTheme = base.textTheme
        .apply(
          fontFamily: uiFont,
          bodyColor: onSurface,
          displayColor: heading,
        )
        .copyWith(
          displayLarge: TextStyle(fontFamily: AppFonts.heading, color: heading, fontWeight: FontWeight.w700),
          displayMedium: TextStyle(fontFamily: AppFonts.heading, color: heading, fontWeight: FontWeight.w700),
          displaySmall: TextStyle(fontFamily: AppFonts.heading, color: heading, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontFamily: AppFonts.heading, color: heading, fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(fontFamily: AppFonts.heading, color: heading, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontFamily: AppFonts.heading, color: heading, fontWeight: FontWeight.w700),
        );

    return base.copyWith(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 12,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            color: onSurface.withValues(alpha: 0.7)),
        iconTheme: IconThemeData(
            color: onSurface.withValues(alpha: 0.8), applyTextScaling: true),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: reader.hairline),
        ),
      ),
      dividerTheme: DividerThemeData(color: reader.hairline, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        height: 64,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 22,
              applyTextScaling: true,
              color: s.contains(WidgetState.selected) ? accent : onSurface.withValues(alpha: 0.5),
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 9.5,
              letterSpacing: 0.6,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
              color: s.contains(WidgetState.selected) ? accent : onSurface.withValues(alpha: 0.6),
            )),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: 0.14),
        side: BorderSide(color: reader.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: onSurface),
        secondaryLabelStyle: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: accent),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(surface),
        elevation: const WidgetStatePropertyAll(0),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStatePropertyAll(BorderSide(color: reader.hairline)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        hintStyle: WidgetStatePropertyAll(
            TextStyle(fontFamily: uiFont, fontSize: 15, color: onSurface.withValues(alpha: 0.5))),
        textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: uiFont, color: onSurface)),
      ),
      extensions: [reader],
    );
  }

  static ThemeData _normal(String uiFont) => _build(
    uiFont: uiFont,
    brightness: Brightness.light,
    scaffold: const Color(0xFFEDE7DA),
    surface: const Color(0xFFE7E0D0),
    onSurface: const Color(0xFF23201A),
    heading: const Color(0xFF1C1813),
    accent: rust,
    reader: const ReaderPalette(
      page: Color(0xFFEDE7DA),
      verseText: Color(0xFF26221A),
      chorusText: Color(0xFF3A2A1E),
      chorusAccent: rust,
      verseNumber: rust,
      muted: Color(0xFF8C8472),
      hairline: Color(0x1A2A2418),
    ),
  );

  static ThemeData _sepia(String uiFont) => _build(
    uiFont: uiFont,
    brightness: Brightness.light,
    scaffold: const Color(0xFFE9DEC8),
    surface: const Color(0xFFE3D7BE),
    onSurface: const Color(0xFF3A2F22),
    heading: const Color(0xFF2E2516),
    accent: rustDeep,
    reader: const ReaderPalette(
      page: Color(0xFFE9DEC8),
      verseText: Color(0xFF362B1D),
      chorusText: Color(0xFF5A4326),
      chorusAccent: Color(0xFF7E3A22),
      verseNumber: Color(0xFF7E3A22),
      muted: Color(0xFF8C7A5E),
      hairline: Color(0x1F4A3A24),
    ),
  );

  static ThemeData _dark(String uiFont) => _build(
    uiFont: uiFont,
    brightness: Brightness.dark,
    scaffold: const Color(0xFF1A1714),
    surface: const Color(0xFF231F1A),
    onSurface: const Color(0xFFEAE3D4),
    heading: const Color(0xFFF2ECDD),
    accent: const Color(0xFFC9703F),
    reader: const ReaderPalette(
      page: Color(0xFF1A1714),
      verseText: Color(0xFFE7E0D2),
      chorusText: Color(0xFFD9B48E),
      chorusAccent: Color(0xFFC9703F),
      verseNumber: Color(0xFFC9703F),
      muted: Color(0xFF9A8E7A),
      hairline: Color(0x1FFFFFFF),
    ),
  );
}
