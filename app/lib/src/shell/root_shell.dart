import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:indirimbo/src/features/sharing/transport.dart' show canJoinSessions, DiscoveredSession;
import 'package:indirimbo/src/state/providers.dart';
import 'package:indirimbo/src/state/settings.dart';
import 'package:indirimbo/src/state/share_state.dart';
import 'package:indirimbo/src/core/app_theme.dart';
import 'package:indirimbo/src/features/sharing/follower_screen.dart';
import 'package:indirimbo/src/features/library/home_screen.dart';
import 'package:indirimbo/src/features/search/search_screen.dart';
import 'package:indirimbo/src/features/favorites/favorites_screen.dart';
import 'package:indirimbo/src/features/settings/settings_screen.dart';

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
    // Trigger the background OTA content check (lazily) and notify when a new
    // dataset has been downloaded (it applies on the next launch).
    ref.listen<AsyncValue<bool>>(datasetUpdateCheckProvider, (_, next) {
      if (next.valueOrNull == true && mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).contentUpdated)),
        );
      }
    });
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

    // "Session nearby" banner: surface a discovered host when the user is idle.
    final session = ref.watch(shareControllerProvider);
    final dismissed = ref.watch(dismissedNearbyProvider);
    final nearby = ref.watch(nearbySessionsProvider).valueOrNull ?? const <DiscoveredSession>[];
    DiscoveredSession? banner;
    if (!immersive && !session.isHosting && !session.isFollowing) {
      for (final s in nearby) {
        if (!dismissed.contains(s.wsUrl)) {
          banner = s;
          break;
        }
      }
    }

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
        body: Stack(
          children: [
            IndexedStack(
              index: index,
              children: [
                for (var i = 0; i < _roots.length; i++)
                  Navigator(
                    key: _navKeys[i],
                    onGenerateRoute: (s) => MaterialPageRoute(builder: (_) => _roots[i]),
                  ),
              ],
            ),
            if (banner != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _NearbyBanner(
                  session: banner,
                  title: t.nearbySession,
                  joinLabel: t.nearbyJoin,
                  onJoin: () => ref.read(shareControllerProvider.notifier).joinSession(banner!),
                  onDismiss: () => ref.read(dismissedNearbyProvider.notifier).state = {
                    ...dismissed,
                    banner!.wsUrl,
                  },
                ),
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

class _NearbyBanner extends StatelessWidget {
  final DiscoveredSession session;
  final String title;
  final String joinLabel;
  final VoidCallback onJoin;
  final VoidCallback onDismiss;
  const _NearbyBanner({
    required this.session,
    required this.title,
    required this.joinLabel,
    required this.onJoin,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(14),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Row(
          children: [
            const Icon(Icons.podcasts_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 9.5,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70)),
                  Text(session.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
            ),
            TextButton(
              onPressed: onJoin,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(joinLabel,
                  style: TextStyle(fontFamily: AppFonts.uiBody, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            ),
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
                    fontFamily: AppFonts.uiBody,
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
