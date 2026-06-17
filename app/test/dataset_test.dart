// Validates the bundled dataset: counts, structure, and A/B variant handling.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimbo/src/data/models.dart';

void main() {
  final json = jsonDecode(File('assets/data/hymns.json').readAsStringSync())
      as Map<String, dynamic>;
  final collections = (json['collections'] as List)
      .map((e) => Collection.fromJson(e as Map<String, dynamic>))
      .toList();
  final songs = (json['songs'] as List)
      .map((e) => Song.fromJson(e as Map<String, dynamic>))
      .toList();

  test('has all 17 collections with songs', () {
    expect(collections.length, 17);
    for (final c in collections) {
      expect(c.songCount, greaterThan(0), reason: c.name);
    }
  });

  test('has the full corpus', () {
    expect(songs.length, greaterThan(5000));
  });

  test('A/B variants are split into distinct songs sharing a number', () {
    final ab = songs.where((s) => s.variant != null).toList();
    expect(ab.length, greaterThan(100));
    // Coll. des Cantiques #1 should have an A and a B with different titles.
    final one = songs
        .where((s) => s.series == 'C-Cantiques' && s.number == 1)
        .toList();
    expect(one.length, 2);
    expect(one.map((s) => s.variant).toSet(), {'A', 'B'});
    expect(one[0].title, isNot(equals(one[1].title)));
  });

  test('songs carry verses and at least some choruses exist', () {
    expect(songs.any((s) => s.stanzas.any((x) => x.type == StanzaType.verse)),
        isTrue);
    expect(songs.any((s) => s.stanzas.any((x) => x.type == StanzaType.chorus)),
        isTrue);
  });
}
