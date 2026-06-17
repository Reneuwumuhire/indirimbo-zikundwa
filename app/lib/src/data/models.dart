// Domain models for the hymnal. Plain immutable value types decoded from the
// bundled assets/data/hymns.json dataset.

enum StanzaType { verse, chorus }

class Stanza {
  final StanzaType type;
  final String text;
  const Stanza({required this.type, required this.text});

  factory Stanza.fromJson(Map<String, dynamic> j) => Stanza(
        type: j['type'] == 'chorus' ? StanzaType.chorus : StanzaType.verse,
        text: j['text'] as String? ?? '',
      );
}

class Song {
  final String id;
  final String series; // collection id, e.g. "A-Foi"
  final int number; // displayed song number within the collection
  final String? variant; // "A" / "B" for songs sharing a number, else null
  final String label; // displayed label, e.g. "1", "1A"
  final String title;
  final String? author; // composer / author credit, if any
  final List<Stanza> stanzas;
  final String lyrics; // flattened text, used for search

  Song({
    required this.id,
    required this.series,
    required this.number,
    required this.variant,
    required this.label,
    required this.title,
    required this.author,
    required this.stanzas,
    required this.lyrics,
  });

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] as String,
        series: j['series'] as String,
        number: j['number'] as int,
        variant: j['variant'] as String?,
        label: j['label'] as String? ?? '${j['number']}',
        title: j['title'] as String? ?? '',
        author: j['author'] as String?,
        stanzas: (j['stanzas'] as List<dynamic>? ?? const [])
            .map((e) => Stanza.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        lyrics: j['lyrics'] as String? ?? '',
      );

  // Lower-cased haystack for fast search (built once per song on load).
  // Includes the artist/author so songs can be found by who performed them.
  late final String searchBlob =
      '$label ${title.toLowerCase()} ${(author ?? '').toLowerCase()} ${lyrics.toLowerCase()}';

  /// Title normalized for display: ALL-CAPS titles (some books store them that
  /// way) are converted to sentence case so every book looks consistent —
  /// only the first letter is capitalized, with common divine names kept
  /// capitalized. Titles that already have mixed case are left untouched.
  late final String displayTitle = displaySongTitle(title);
}

const _properNouns = <String>{
  'yesu', 'yezu', 'imana', 'mungu', 'dieu', 'jesus', 'jésus', 'christ',
  'kristo', 'yehova', 'yahweh', 'roho', 'mwami', 'mana', 'alleluia', 'alleluya',
  'haleluya', 'jehovah',
};

String _capitalizeFirstLetter(String w) {
  for (var i = 0; i < w.length; i++) {
    final ch = w[i];
    if (ch.toLowerCase() != ch.toUpperCase()) {
      return w.substring(0, i) + ch.toUpperCase() + w.substring(i + 1);
    }
  }
  return w;
}

/// Sentence-cases a title only if it is entirely uppercase.
String displaySongTitle(String raw) {
  final t = raw.trim();
  if (t.isEmpty || t != t.toUpperCase()) return raw; // already has lower case
  final words = t.toLowerCase().split(' ');
  for (var i = 0; i < words.length; i++) {
    final key = words[i].replaceAll(RegExp(r"[^a-zà-ÿ]"), '');
    if (key.isNotEmpty && _properNouns.contains(key)) {
      words[i] = _capitalizeFirstLetter(words[i]);
    }
  }
  // Always capitalize the first non-empty word.
  for (var i = 0; i < words.length; i++) {
    if (words[i].trim().isNotEmpty) {
      words[i] = _capitalizeFirstLetter(words[i]);
      break;
    }
  }
  return words.join(' ');
}

class Collection {
  final String id;
  final String name;
  final int songCount;
  const Collection({required this.id, required this.name, required this.songCount});

  factory Collection.fromJson(Map<String, dynamic> j) => Collection(
        id: j['id'] as String,
        name: j['name'] as String,
        songCount: j['songCount'] as int? ?? 0,
      );
}

class Dataset {
  final List<Collection> collections;
  final List<Song> songs;
  const Dataset({required this.collections, required this.songs});
}
