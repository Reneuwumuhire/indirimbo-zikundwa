import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/favorites.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../state/share_state.dart';
import '../theme/app_theme.dart';
import '../theme/font_combos.dart';
import 'widgets/lyrics_viewer.dart';

/// Full-screen "follower" view: mirrors the song and scroll position the host is
/// sharing. Shown as an overlay whenever the user is following a session.
class FollowerScreen extends ConsumerStatefulWidget {
  const FollowerScreen({super.key});

  @override
  ConsumerState<FollowerScreen> createState() => _FollowerScreenState();
}

class _FollowerScreenState extends ConsumerState<FollowerScreen> {
  final _scroll = ScrollController();
  double _lastApplied = -1;
  String? _lastSongId;

  /// Whether we mirror the host's scroll. The viewer can scroll on their own,
  /// which pauses scroll-following until they tap "resume" (or the song changes).
  bool _following = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _applyScroll(double fraction) {
    if (!_scroll.hasClients) return;
    final target = fraction * _scroll.position.maxScrollExtent;
    if ((target - _scroll.offset).abs() < 2) return;
    _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
  }

  void _resume() {
    setState(() => _following = true);
    final v = ref.read(shareControllerProvider).followedView;
    if (v != null) {
      _lastApplied = v.scroll;
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyScroll(v.scroll));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ref.watch(stringsProvider);
    final palette = theme.extension<ReaderPalette>()!;
    final settings = ref.watch(settingsProvider);
    final combo = ref.watch(fontComboProvider);
    final session = ref.watch(shareControllerProvider);
    final repo = ref.watch(repositoryProvider).valueOrNull;

    final view = session.followedView;
    if (view != null) {
      // A new song always re-syncs (and resumes following).
      if (view.songId != _lastSongId) {
        _lastSongId = view.songId;
        _following = true;
      }
      // Mirror the host's scroll only while following.
      if (_following && view.scroll != _lastApplied) {
        _lastApplied = view.scroll;
        WidgetsBinding.instance.addPostFrameCallback((_) => _applyScroll(view.scroll));
      }
    }

    final Song? song =
        (view != null && repo != null) ? repo.byId(view.songId) : null;
    final isFav = song != null && ref.watch(favoritesProvider).contains(song.id);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: palette.page,
        body: Column(
          children: [
            _FollowerHeader(
              name: session.sessionName ?? t.shareTitle,
              liveLabel: t.shareLiveBadge,
              leaveLabel: t.shareLeave,
              connected: session.connected,
              isFav: isFav,
              onFav: song == null
                  ? null
                  : () => ref.read(favoritesProvider.notifier).toggle(song.id),
              onLeave: () => ref.read(shareControllerProvider.notifier).leave(),
            ),
            if (!session.connected)
              _Banner(text: t.shareDisconnected, color: theme.colorScheme.error),
            Expanded(
              child: song == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 2.4)),
                          const SizedBox(height: 16),
                          Text(t.shareWaiting,
                              style: TextStyle(fontFamily: AppFonts.body, color: palette.muted)),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        // The viewer may scroll freely; doing so pauses
                        // scroll-following until they tap "resume".
                        NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollStartNotification &&
                                n.dragDetails != null &&
                                _following) {
                              setState(() => _following = false);
                            }
                            return false;
                          },
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: ListView(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(24, 22, 24, 56),
                            children: [
                              Text(
                                '${repo!.collection(song.series).name} · N° ${song.label}',
                                style: TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontSize: 12.5,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                song.displayTitle,
                                style: combo.titleStyle(
                                  theme.textTheme.displaySmall,
                                  fontSize: (settings.fontSize + 9).clamp(24, 44),
                                  color: palette.verseText,
                                ).copyWith(height: 1.18),
                              ),
                              if (song.author != null && song.author!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(song.author!,
                                    style: TextStyle(
                                        fontFamily: AppFonts.body,
                                        fontSize: 13.5,
                                        fontStyle: FontStyle.italic,
                                        color: palette.muted)),
                              ],
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Container(width: 34, height: 2, color: theme.colorScheme.primary),
                                  Expanded(child: Container(height: 1, color: palette.hairline)),
                                ],
                              ),
                              const SizedBox(height: 28),
                              LyricsViewer(song: song, settings: settings),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!_following)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 18,
                            child: Center(
                              child: _ResumeButton(label: t.shareResume, onTap: _resume),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ResumeButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(30),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sync_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowerHeader extends StatelessWidget {
  final String name;
  final String liveLabel;
  final String leaveLabel;
  final bool connected;
  final bool isFav;
  final VoidCallback? onFav;
  final VoidCallback onLeave;
  const _FollowerHeader({
    required this.name,
    required this.liveLabel,
    required this.leaveLabel,
    required this.connected,
    required this.isFav,
    required this.onFav,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 10, 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: connected ? Colors.white.withValues(alpha: 0.2) : Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: connected ? Colors.redAccent : Colors.white54),
                    ),
                    const SizedBox(width: 6),
                    Text(liveLabel,
                        style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              if (onFav != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onFav,
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                      size: 20, color: Colors.white),
                ),
              TextButton.icon(
                onPressed: onLeave,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(leaveLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: AppFonts.body, fontSize: 12.5, color: color)),
    );
  }
}
