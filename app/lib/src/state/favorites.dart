// Favorite song ids, persisted with SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings.dart' show sharedPrefsProvider;

final favoritesProvider =
    NotifierProvider<FavoritesController, Set<String>>(FavoritesController.new);

class FavoritesController extends Notifier<Set<String>> {
  static const _key = 'favorites.ids';

  @override
  Set<String> build() {
    final p = ref.read(sharedPrefsProvider);
    return (p.getStringList(_key) ?? const []).toSet();
  }

  bool isFavorite(String id) => state.contains(id);

  void toggle(String id) {
    final next = {...state};
    if (!next.add(id)) next.remove(id);
    state = next;
    ref.read(sharedPrefsProvider).setStringList(_key, next.toList());
  }
}
