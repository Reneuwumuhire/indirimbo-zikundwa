// Text utilities for forgiving search: accent-folding normalization, tokenizing,
// and Damerau–Levenshtein edit distance for typo tolerance.

/// Accent/diacritic folding for the Latin scripts the corpus uses (Kinyarwanda,
/// French, Swahili). Lower-cases and strips accents so "Umukíza" matches
/// "umukiza" and "priere" matches "prière".
String foldText(String input) {
  final lower = input.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    out.write(_fold[ch] ?? ch);
  }
  return out.toString();
}

const Map<String, String> _fold = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ę': 'e', 'ě': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ñ': 'n', 'ń': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u',
  'ý': 'y', 'ÿ': 'y',
  'š': 's', 'ś': 's', 'ş': 's',
  'ž': 'z', 'ź': 'z', 'ż': 'z',
  'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
  '’': "'", '‘': "'", '`': "'", '´': "'",
};

final _wordSplit = RegExp(r"[^a-z0-9]+");

/// Fold + split a string into lowercase alphanumeric tokens.
List<String> tokenize(String input) =>
    foldText(input).split(_wordSplit).where((t) => t.isNotEmpty).toList();

/// Damerau–Levenshtein (optimal string alignment) distance — counts insertions,
/// deletions, substitutions and adjacent transpositions. Used to rank fuzzy
/// matches so a small typo still finds the intended word. Returns early once the
/// best possible distance exceeds [max] (a cheap cutoff for large dictionaries).
int editDistance(String a, String b, {int max = 1 << 30}) {
  if (a == b) return 0;
  final la = a.length, lb = b.length;
  if ((la - lb).abs() > max) return max + 1;
  if (la == 0) return lb;
  if (lb == 0) return la;

  var prev2 = List<int>.filled(lb + 1, 0);
  var prev = List<int>.generate(lb + 1, (j) => j);
  var cur = List<int>.filled(lb + 1, 0);

  for (var i = 1; i <= la; i++) {
    cur[0] = i;
    var rowMin = cur[0];
    final ai = a.codeUnitAt(i - 1);
    for (var j = 1; j <= lb; j++) {
      final cost = ai == b.codeUnitAt(j - 1) ? 0 : 1;
      var v = _min3(cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost);
      if (i > 1 &&
          j > 1 &&
          ai == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        v = v < prev2[j - 2] + 1 ? v : prev2[j - 2] + 1;
      }
      cur[j] = v;
      if (v < rowMin) rowMin = v;
    }
    if (rowMin > max) return max + 1;
    final tmp = prev2;
    prev2 = prev;
    prev = cur;
    cur = tmp;
  }
  return prev[lb];
}

int _min3(int a, int b, int c) {
  final m = a < b ? a : b;
  return m < c ? m : c;
}

/// Allowed typos for a query word of the given length (longer words tolerate
/// more). 0 for very short words so "is" doesn't fuzzily match everything.
int fuzzyThreshold(int wordLength) {
  if (wordLength <= 3) return 0;
  if (wordLength <= 6) return 1;
  return 2;
}
