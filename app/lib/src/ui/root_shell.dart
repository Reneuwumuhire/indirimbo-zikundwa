import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../share/transport.dart' show canJoinSessions;
import '../state/providers.dart';
import '../state/settings.dart';
import '../state/share_state.dart';
import '../theme/app_theme.dart';
import 'follower_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';

/// Root shell with a persistent bottom navigation bar. Each tab owns its own
/// Navigator, so pushed routes (collection, reader) keep the bottom bar visible.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});
  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  final _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    // Deep link: opening the app with ?join=ws://host:port auto-follows a host
    // (handy on the web, where a shared link is the easiest way to join).
    if (kIsWeb && canJoinSessions) {
      final join = Uri.base.queryParameters['join'];
      if (join != null && join.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(shareControllerProvider.notifier).joinByAddress(join);
        });
      }
    }
  }

  static const _roots = <Widget>[
    HomeScreen(),
    SearchScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    return repo.when(
      loading: () => const _Splash(),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(ref.read(stringsProvider).loadError(e), textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (_) {
        final following =
            ref.watch(shareControllerProvider.select((s) => s.isFollowing));
        return Stack(
          children: [
            _shell(),
            if (following) const Positioned.fill(child: FollowerScreen()),
          ],
        );
      },
    );
  }

  Widget _shell() {
    final index = ref.watch(selectedTabProvider);
    final t = ref.watch(stringsProvider);
    final immersive = ref.watch(immersiveProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navKeys[index].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (index != 0) {
          ref.read(selectedTabProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < _roots.length; i++)
              Navigator(
                key: _navKeys[i],
                onGenerateRoute: (s) => MaterialPageRoute(builder: (_) => _roots[i]),
              ),
          ],
        ),
        bottomNavigationBar: immersive
            ? null
            : NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            if (i == index) {
              _navKeys[i].currentState?.popUntil((r) => r.isFirst);
            } else {
              ref.read(selectedTabProvider.notifier).state = i;
            }
          },
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.library_music_outlined),
                selectedIcon: const Icon(Icons.library_music),
                label: t.navBooks),
            NavigationDestination(
                icon: const Icon(Icons.search_outlined),
                selectedIcon: const Icon(Icons.search),
                label: t.navSearch),
            NavigationDestination(
                icon: const Icon(Icons.favorite_outline),
                selectedIcon: const Icon(Icons.favorite),
                label: t.navFavorites),
            NavigationDestination(
                icon: const Icon(Icons.tune_outlined),
                selectedIcon: const Icon(Icons.tune),
                label: t.navSettings),
          ],
        ),
      ),
    );
  }
}

class _Splash extends ConsumerWidget {
  const _Splash();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(stringsProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.brandGradient,
              ),
              child: const Icon(Icons.menu_book_rounded, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 22),
            Text('Indirimbo Zikundwa', style: theme.textTheme.titleLarge?.copyWith(fontSize: 24)),
            const SizedBox(height: 6),
            Text(t.splashSub,
                style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 28),
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}
