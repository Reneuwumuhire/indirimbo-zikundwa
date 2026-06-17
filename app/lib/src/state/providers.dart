// Core providers: the repository (async-loaded) plus search wiring.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/hymn_repository.dart';
import '../data/models.dart';

final repositoryProvider = FutureProvider<HymnRepository>((ref) async {
  return HymnRepository.load();
});

/// Selected bottom-navigation tab (0=Recueils,1=Recherche,2=Favoris,3=Réglages).
final selectedTabProvider = StateProvider<int>((_) => 0);

/// The current global search query.
final searchQueryProvider = StateProvider<String>((_) => '');

/// Whether the reader is in distraction-free fullscreen mode (toggled by a
/// double-tap on the lyrics). When true the bottom navigation is hidden too.
final immersiveProvider = StateProvider<bool>((_) => false);

/// Results for the current query (empty when query is blank).
final searchResultsProvider = Provider<List<Song>>((ref) {
  final repo = ref.watch(repositoryProvider).valueOrNull;
  final q = ref.watch(searchQueryProvider);
  if (repo == null) return const [];
  return repo.search(q);
});
