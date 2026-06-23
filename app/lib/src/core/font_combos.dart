import 'package:flutter/material.dart';

/// A user-selectable pairing of a title font and a lyrics font.
class FontCombo {
  final String name;
  final String title; // family for song titles
  final FontWeight titleWeight;
  final bool titleItalic;
  final String lyrics; // family for lyrics / reading body

  const FontCombo({
    required this.name,
    required this.title,
    required this.lyrics,
    this.titleWeight = FontWeight.w700,
    this.titleItalic = false,
  });
}

/// Index 0 is the default ("Cantica" classic). The rest are the curated examples.
const fontCombos = <FontCombo>[
  FontCombo(name: 'Classique · Playfair & Spectral', title: 'Playfair Display', lyrics: 'Spectral'),
  FontCombo(name: 'Playfair Display & Inter', title: 'Playfair Display', lyrics: 'Inter'),
  FontCombo(name: 'Montserrat & Lora', title: 'Montserrat', titleWeight: FontWeight.w900, lyrics: 'Lora'),
  FontCombo(name: 'Oswald & Merriweather', title: 'Oswald', titleWeight: FontWeight.w500, lyrics: 'Merriweather'),
  FontCombo(name: 'Syne & Plus Jakarta Sans', title: 'Syne', titleWeight: FontWeight.w800, lyrics: 'Plus Jakarta Sans'),
  FontCombo(
      name: 'Cormorant Garamond & Source Sans 3',
      title: 'Cormorant Garamond',
      titleWeight: FontWeight.w600,
      titleItalic: true,
      lyrics: 'Source Sans 3'),
  FontCombo(name: 'Archivo Black & Roboto Mono', title: 'Archivo Black', titleWeight: FontWeight.w400, lyrics: 'Roboto Mono'),
  FontCombo(name: 'Fraunces & DM Sans', title: 'Fraunces', lyrics: 'DM Sans'),
  FontCombo(name: 'Space Grotesk & Arimo', title: 'Space Grotesk', lyrics: 'Arimo'),
];

extension FontComboX on FontCombo {
  /// A title TextStyle for this combo, merged onto [base].
  TextStyle titleStyle(TextStyle? base, {double? fontSize, Color? color}) =>
      (base ?? const TextStyle()).copyWith(
        fontFamily: title,
        fontWeight: titleWeight,
        fontStyle: titleItalic ? FontStyle.italic : FontStyle.normal,
        fontSize: fontSize,
        color: color,
      );
}
