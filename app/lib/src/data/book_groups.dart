// Language grouping for the collections. Hymnals carry no language metadata, so
// each collection is assigned a group here (confirmed with the project owner).
// Labels are fixed (not translated by the FR/EN UI toggle).

/// A language family that collections are grouped under.
enum BookGroup { kirundi, kinyarwanda, swahili, french, combined }

extension BookGroupX on BookGroup {
  /// Fixed display label (same in every UI language).
  String get label => switch (this) {
        BookGroup.kirundi => 'Kirundi',
        BookGroup.kinyarwanda => 'Kinyarwanda',
        BookGroup.swahili => 'Swahili',
        BookGroup.french => 'Français',
        BookGroup.combined => 'Combiné',
      };

  /// Short code shown on book covers (like EN / FR in the reference design).
  String get code => switch (this) {
        BookGroup.kirundi => 'RN',
        BookGroup.kinyarwanda => 'RW',
        BookGroup.swahili => 'SW',
        BookGroup.french => 'FR',
        BookGroup.combined => 'MIX',
      };
}

/// Collection id → language group.
const _groupByCollection = <String, BookGroup>{
  'Umuco': BookGroup.kirundi,
  'Umuco-1': BookGroup.kirundi,
  'Umuco-2': BookGroup.kirundi,
  'Ikirundi': BookGroup.kirundi,
  'Izigisenyi': BookGroup.kinyarwanda,
  'Gushimisha': BookGroup.kinyarwanda,
  'Agakiza': BookGroup.kinyarwanda,
  'Wokovu': BookGroup.swahili,
  'N-Mungu': BookGroup.swahili,
  'T-Rohoni': BookGroup.swahili,
  'A-Foi': BookGroup.french,
  'C-Victoire': BookGroup.french,
  'C-Seulement': BookGroup.french,
  'Impimbano': BookGroup.combined,
  'C-Cantiques': BookGroup.combined,
  'Chorus': BookGroup.combined,
  'Izindi': BookGroup.combined,
};

/// Group for a collection id (falls back to Combined for anything unmapped).
BookGroup bookGroupOf(String collectionId) =>
    _groupByCollection[collectionId] ?? BookGroup.combined;

/// The order groups are displayed in (chips and section headers).
const bookGroupOrder = <BookGroup>[
  BookGroup.kirundi,
  BookGroup.kinyarwanda,
  BookGroup.swahili,
  BookGroup.french,
  BookGroup.combined,
];
