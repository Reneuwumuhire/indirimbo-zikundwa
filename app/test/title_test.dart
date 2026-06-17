import 'package:flutter_test/flutter_test.dart';
import 'package:indirimbo/src/data/models.dart';

void main() {
  group('displaySongTitle', () {
    test('all-caps titles become sentence case', () {
      expect(displaySongTitle("JEWE KW'ISI ND'UMUSHITSI"), "Jewe kw'isi nd'umushitsi");
      expect(displaySongTitle('MBIGUNI JUU'), 'Mbiguni juu');
    });

    test('divine names stay capitalized', () {
      expect(displaySongTitle('MWAMI YESU JE NDAGUSHIMA'), 'Mwami Yesu je ndagushima');
      expect(displaySongTitle('MUSIFU MUNGU KWA BARAKA'), 'Musifu Mungu kwa baraka');
    });

    test('already mixed-case titles are left untouched', () {
      expect(displaySongTitle('Yera, Yera, Yera'), 'Yera, Yera, Yera');
      expect(displaySongTitle('Grand Dieu, nous te louons'), 'Grand Dieu, nous te louons');
      expect(displaySongTitle("Qu'on batte des mains"), "Qu'on batte des mains");
    });
  });
}
