import 'package:flutter_test/flutter_test.dart';
import 'package:indirimbo/src/features/reader/lyrics_viewer.dart';

void main() {
  group('verseLines', () {
    test('breaks a flowing verse into clause lines', () {
      final lines = verseLines(
          "Jewe kw'isi nd'umushitsi, ndi mu Rugendo rwo kuj'iwacu, sindab'inyuma ndab'imbere, mpanz'amaso iy'iwacu.");
      expect(lines.length, greaterThan(1));
      // Every line should end at clause punctuation (printed-hymnal feel).
      for (final l in lines) {
        expect(RegExp(r'[,;:.!?…»]$').hasMatch(l), isTrue, reason: l);
      }
    });

    test('does not produce choppy one-word lines from repeated commas', () {
      final lines = verseLines(
          'Paix! Salut! en Jésus, Cloches, résonnez encore; Paix! Salut! en Jésus, Recevons tous ce Trésor.');
      // No "Paix!" / "Salut!" alone — short clauses merge.
      expect(lines.every((l) => l.length >= 8), isTrue, reason: lines.join(' | '));
    });

    test('plain text without punctuation stays one line', () {
      expect(verseLines('Alleluia amen'), ['Alleluia amen']);
    });
  });
}
