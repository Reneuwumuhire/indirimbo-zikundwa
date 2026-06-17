// Lightweight in-app localization (French / English). The hymn *content*
// (titles, lyrics, collection names) stays in its original language; only the
// app chrome is translated. Exposed via [stringsProvider] in settings.dart.

import '../theme/app_theme.dart';

enum AppLanguage { fr, en }

extension AppLanguageX on AppLanguage {
  String get label => this == AppLanguage.fr ? 'Français' : 'English';
  String get code => this == AppLanguage.fr ? 'FR' : 'EN';
}

class Strings {
  final AppLanguage lang;
  const Strings._(this.lang);

  static const _fr = Strings._(AppLanguage.fr);
  static const _en = Strings._(AppLanguage.en);
  static Strings of(AppLanguage l) => l == AppLanguage.fr ? _fr : _en;

  String _t(String fr, String en) => lang == AppLanguage.fr ? fr : en;

  // Navigation
  String get navBooks => _t('Recueils', 'Books');
  String get navSearch => _t('Recherche', 'Search');
  String get navFavorites => _t('Favoris', 'Favorites');
  String get navSettings => _t('Réglages', 'Settings');

  // Home
  String get welcome => 'MURAKAZA NEZA';
  String get discover => _t('À découvrir', 'Discover');
  String get seeAll => _t('Voir tout', 'See all');
  String get allBooks => _t('Tous les recueils', 'All books');
  String get all => _t('Tous', 'All');
  String get bookLabel => _t('RECUEIL', 'COLLECTION');
  String songs(int n) => _t('$n chants', '$n songs');
  String get songsUnit => _t('CHANTS', 'SONGS');
  String get searchPill =>
      _t('Rechercher un chant, un numéro…', 'Search a song, a number…');

  // Search
  String get searchHint =>
      _t('Rechercher dans tous les recueils…', 'Search across all books…');
  String results(int n) => _t('$n résultat(s)', '$n result(s)');
  String get searchPrompt =>
      _t('Cherchez par numéro, titre ou parole', 'Search by number, title or lyrics');
  String get noResults => _t('Aucun chant trouvé.', 'No song found.');

  // Favorites
  String get favEmptyTitle =>
      _t('Aucun favori pour le moment', 'No favorites yet');
  String get favEmptyHint =>
      _t('Touchez ♥ sur un chant pour l’ajouter', 'Tap ♥ on a song to add it');

  // Settings
  String get libraryTile => _t('Bibliothèque', 'Library');
  String libraryDesc(int total, int books) => _t(
        '$total chants · $books recueils — disponible hors‑ligne',
        '$total songs · $books books — available offline',
      );
  String get aboutTile => _t('À propos', 'About');
  String get aboutDesc => _t(
        'Indirimbo Zikundwa · lecteur de cantiques (v1.0)',
        'Indirimbo Zikundwa · hymn reader (v1.0)',
      );
  String get languageSection => _t('Langue', 'Language');
  String get fontComboSection => _t('Combinaison de polices', 'Font pairing');
  String get layoutSection => _t('Disposition des recueils', 'Books layout');
  String get layoutGrid => _t('Grille', 'Grid');
  String get layoutList => _t('Liste', 'List');

  // Reader controls
  String get themeSection => _t('Thème', 'Theme');
  String get fontSection => _t('Police', 'Font');
  String get textSize => _t('Taille du texte', 'Text size');
  String get lineSpacing => _t('Interligne', 'Line spacing');
  String get sample => _t(
        'Béni soit le lien qui unit nos cœurs en Jésus-Christ.',
        'Blest be the tie that binds our hearts in Christian love.',
      );
  String themeModeName(AppThemeMode m) => switch (m) {
        AppThemeMode.normal => _t('Clair', 'Light'),
        AppThemeMode.sepia => _t('Sépia', 'Sepia'),
        AppThemeMode.dark => _t('Sombre', 'Dark'),
      };

  // Collection detail
  String get tabSongs => _t('Chants', 'Songs');
  String get tabAbout => _t('À propos', 'About');
  String songsOffline(int n) =>
      _t('$n chants · hors‑ligne', '$n songs · offline');
  String get aboutBookHeader =>
      _t('À propos de ce recueil', 'About this book');
  String aboutBookBody(String name, int count) => _t(
        '« $name » fait partie de la collection Indirimbo Zikundwa. '
            'Ce recueil contient $count chants, disponibles entièrement '
            'hors‑ligne pour la lecture et la louange.',
        '“$name” is part of the Indirimbo Zikundwa collection. '
            'This book contains $count songs, fully available offline '
            'for reading and worship.',
      );
  String get statSongs => _t('Chants', 'Songs');
  String get statOffline => _t('Hors‑ligne', 'Offline');
  String get shareSoon =>
      _t('Partage bientôt disponible', 'Sharing coming soon');

  // Reader
  String verseLabel(int n) => _t('COUPLET $n', 'VERSE $n');
  String get refrainLabel => _t('REFRAIN', 'CHORUS');
  String version(String v) => _t('Version $v', 'Version $v');
  String get songNotFound => _t('Chant introuvable', 'Song not found');
  String get display => _t('Affichage', 'Display');

  // Live share
  String get shareTitle => _t('Partage en direct', 'Live share');
  String get shareSubtitle => _t(
        'Partagez cette vue avec les personnes sur le même réseau Wi‑Fi.',
        'Share this view with people on the same Wi‑Fi network.',
      );
  String get shareHostAction => _t('Partager ma vue', 'Share my view');
  String get shareHostHint =>
      _t('Les autres suivront ce que vous lisez', 'Others will follow what you read');
  String get shareJoinAction => _t('Rejoindre une session', 'Join a session');
  String get shareJoinHint =>
      _t('Suivre quelqu’un qui partage', 'Follow someone who is sharing');
  String get shareUnsupported => _t(
        'Le partage en direct nécessite l’application mobile (indisponible sur le web).',
        'Live sharing requires the mobile app (not available on the web).',
      );
  String get shareHostingTitle => _t('Vous partagez', 'You’re sharing');
  String shareFollowers(int n) =>
      _t('$n personne(s) connectée(s)', '$n person(s) connected');
  String get shareStop => _t('Arrêter le partage', 'Stop sharing');
  String shareFollowingTitle(String name) => _t('Vous suivez $name', 'Following $name');
  String get shareLeave => _t('Quitter', 'Leave');
  String get shareSearching => _t('Recherche de sessions…', 'Looking for sessions…');
  String get shareNoSessions =>
      _t('Aucune session trouvée sur le réseau.', 'No sessions found on the network.');
  String get shareJoinByAddress => _t('Rejoindre par adresse', 'Join by address');
  String get shareAddressHint =>
      _t('ex. 192.168.1.5:54123', 'e.g. 192.168.1.5:54123');
  String get shareConnect => _t('Se connecter', 'Connect');
  String get shareHostUnavailableWeb => _t(
        'L’hébergement n’est pas possible dans le navigateur — utilisez l’app mobile pour héberger. Vous pouvez rejoindre une session ci‑dessous.',
        'Hosting isn’t possible in the browser — use the mobile app to host. You can still join a session below.',
      );
  String get shareJoinUrlsTitle =>
      _t('Adresses pour rejoindre', 'Addresses to join');
  String get shareCopied => _t('Copié', 'Copied');
  String get shareWaiting => _t('En attente du partage…', 'Waiting for the share…');
  String get shareResume => _t('Reprendre le suivi', 'Resume following');
  String get shareDisconnected => _t('Hôte déconnecté', 'Host disconnected');
  String get shareLiveBadge => _t('EN DIRECT', 'LIVE');
  String get shareBack => _t('Retour', 'Back');

  // Misc
  String loadError(Object e) =>
      _t('Erreur de chargement des chants:\n$e', 'Failed to load songs:\n$e');
  String get splashSub => _t('Recueil de cantiques', 'Hymn collection');
}
