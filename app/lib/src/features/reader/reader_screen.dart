import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:indirimbo/src/data/models.dart';
import 'package:indirimbo/src/features/sharing/transport.dart';
import 'package:indirimbo/src/state/favorites.dart';
import 'package:indirimbo/src/state/providers.dart';
import 'package:indirimbo/src/state/settings.dart';
import 'package:indirimbo/src/state/share_state.dart';
import 'package:indirimbo/src/core/strings.dart';
import 'package:indirimbo/src/core/app_theme.dart';
import 'package:indirimbo/src/core/font_combos.dart';
import 'package:indirimbo/src/features/sharing/share_sheet.dart';
import 'package:indirimbo/src/features/reader/lyrics_viewer.dart';
import 'package:indirimbo/src/features/reader/reader_controls.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String songId;
  const ReaderScreen({super.key, required this.songId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _scroll = ScrollController();
  DateTime _lastBroadcast = DateTime.fromMillisecondsSinceEpoch(0);

  // Pinch-to-zoom state (zoom multiplies the reading font size).
  final Map<int, Offset> _pointers = {};
  double _zoom = 1.0;
  double _baseDist = 0;
  double _baseZoom = 1.0;
  bool _pinching = false;

  bool? _wakeApplied;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _broadcast(force: true));
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    // Leaving the reader: drop fullscreen, restore system UI, release wakelock.
    ref.read(immersiveProvider.notifier).state = false;
    _setSystemUi(false);
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  void _onScroll() => _broadcast();

  void _setSystemUi(bool immersive) {
    try {
      SystemChrome.setEnabledSystemUIMode(
          immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    } catch (_) {}
  }

  void _toggleImmersive() {
    final next = !ref.read(immersiveProvider);
    ref.read(immersiveProvider.notifier).state = next;
    _setSystemUi(next);
  }

  void _applyWakelock(bool on) {
    if (_wakeApplied == on) return;
    _wakeApplied = on;
    try {
      on ? WakelockPlus.enable() : WakelockPlus.disable();
    } catch (_) {}
  }

  double _distance() {
    final pts = _pointers.values.toList();
    return (pts[0] - pts[1]).distance;
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _baseDist = _distance();
      _baseZoom = _zoom;
      setState(() => _pinching = true);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    if (_pinching && _pointers.length >= 2 && _baseDist > 0) {
      final z = (_baseZoom * _distance() / _baseDist).clamp(0.7, 2.6);
      if (z != _zoom) setState(() => _zoom = z);
    }
  }

  void _onPointerUp(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.length < 2 && _pinching) setState(() => _pinching = false);
  }

  void _broadcast({bool force = false}) {
    final session = ref.read(shareControllerProvider);
    if (!session.isHosting) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastBroadcast).inMilliseconds < 90) return;
    _lastBroadcast = now;
    double frac = 0;
    if (_scroll.hasClients && _scroll.position.maxScrollExtent > 0) {
      frac = (_scroll.offset / _scroll.position.maxScrollExtent).clamp(0.0, 1.0);
    }
    ref
        .read(shareControllerProvider.notifier)
        .updateHostView(SharedView(songId: widget.songId, scroll: frac));
  }

  // Minimum horizontal fling speed (px/s) to treat a drag as a song swipe.
  static const double _swipeVelocity = 240;

  // dir: +1 the new song enters from the right (next), -1 from the left (prev),
  // 0 uses the default platform transition (no directional slide).
  void _go(Song s, {int dir = 0}) {
    final route = dir == 0
        ? MaterialPageRoute(builder: (_) => ReaderScreen(songId: s.id))
        : PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 260),
            reverseTransitionDuration: const Duration(milliseconds: 260),
            pageBuilder: (_, __, ___) => ReaderScreen(songId: s.id),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween(begin: Offset(dir.toDouble(), 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
    Navigator.of(context).pushReplacement(route);
  }

  // Swipe right -> previous song, swipe left -> next song (mirrors the buttons).
  void _onHorizontalSwipe(DragEndDetails details, {Song? prev, Song? next}) {
    if (_pinching) return;
    final v = details.primaryVelocity ?? 0;
    if (v > _swipeVelocity) {
      if (prev != null) _go(prev, dir: -1);
    } else if (v < -_swipeVelocity) {
      if (next != null) _go(next, dir: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider).requireValue;
    final t = ref.watch(stringsProvider);
    final song = repo.byId(widget.songId);
    if (song == null) {
      return Scaffold(body: Center(child: Text(t.songNotFound)));
    }
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final combo = ref.watch(fontComboProvider);
    final palette = theme.extension<ReaderPalette>()!;
    final collection = repo.collection(song.series);
    final isFav = ref.watch(favoritesProvider).contains(song.id);
    final session = ref.watch(shareControllerProvider);
    final immersive = ref.watch(immersiveProvider);

    _applyWakelock(settings.keepScreenOn);

    ref.listen(shareControllerProvider.select((s) => s.isHosting), (_, hosting) {
      if (hosting) _broadcast(force: true);
    });

    // Effective (pinch-zoomed) font size for the title + lyrics.
    final fs = settings.fontSize * _zoom;
    final zoomed = settings.copyWith(fontSize: fs);

    final inSeries = repo.songsIn(song.series);
    final pos = inSeries.indexWhere((s) => s.id == song.id);
    final prev = pos > 0 ? inSeries[pos - 1] : null;
    final next = (pos >= 0 && pos < inSeries.length - 1) ? inSeries[pos + 1] : null;

    final variants = repo
        .songsIn(song.series)
        .where((s) => s.number == song.number && s.variant != null)
        .toList();

    final reading = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _toggleImmersive,
      onHorizontalDragEnd: (d) => _onHorizontalSwipe(d, prev: prev, next: next),
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: (e) => _onPointerUp(e.pointer),
        onPointerCancel: (e) => _onPointerUp(e.pointer),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              // SelectionArea makes the title + lyrics selectable (long-press),
              // so users can copy/share text via the native selection toolbar.
              child: SelectionArea(
                child: ListView(
              controller: _scroll,
              physics: _pinching ? const NeverScrollableScrollPhysics() : null,
              padding: EdgeInsets.fromLTRB(24, immersive ? 8 : 18, 24, 40),
              children: [
                Text('#${song.label}',
                    style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: theme.colorScheme.primary)),
                const SizedBox(height: 10),
                Text(
                  song.displayTitle,
                  style: combo.titleStyle(
                    theme.textTheme.displaySmall,
                    fontSize: (fs + 9).clamp(24, 56),
                    color: palette.verseText,
                  ).copyWith(height: 1.16),
                ),
                if (song.author != null && song.author!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(song.author!,
                      style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 11.5,
                          letterSpacing: 0.3,
                          color: palette.muted)),
                ],
                const SizedBox(height: 18),
                Container(width: 40, height: 1.5, color: palette.muted.withValues(alpha: 0.5)),
                if (variants.length > 1) ...[
                  const SizedBox(height: 18),
                  _VariantSwitcher(current: song, variants: variants, label: t.version),
                ],
                const SizedBox(height: 26),
                LyricsViewer(song: song, settings: zoomed),
                const SizedBox(height: 6),
                _EndOfSong(label: t.endOfSong),
              ],
            ),
            ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: palette.page,
      body: Column(
        children: [
          if (!immersive)
            _TopBar(
              bookName: collection.name,
              isFav: isFav,
              onBack: () => Navigator.of(context).maybePop(),
              onFav: () => ref.read(favoritesProvider.notifier).toggle(song.id),
              onDisplay: () => _openDisplaySheet(context, t.display),
              onShare: () => showShareSheet(context, song.id),
            ),
          if (!immersive && session.isHosting)
            _HostingBanner(
              liveLabel: t.shareLiveBadge,
              followersLabel: t.shareFollowers(session.followers),
              stopLabel: t.shareStop,
              onStop: () => ref.read(shareControllerProvider.notifier).leave(),
            ),
          Expanded(
            child: SafeArea(
              top: immersive,
              bottom: immersive,
              // Lyrics size is controlled by the reader's own font-size + pinch
              // zoom, so opt out of the global app text scale here.
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.noScaling),
                child: reading,
              ),
            ),
          ),
          if (!immersive)
            _BottomBar(
              number: song.label,
              prevLabel: t.shareBack,
              onPrev: prev == null ? null : () => _go(prev, dir: -1),
              onNext: next == null ? null : () => _go(next, dir: 1),
              onPick: () => _openSongPicker(inSeries, song, collection.name, t),
            ),
        ],
      ),
    );
  }

  void _openDisplaySheet(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(22, 4, 22, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              const ReaderControls(),
            ],
          ),
        ),
      ),
    );
  }

  // Quick switch to another song in the same book: jump by number/title or pick
  // from the list. Tapping a song replaces the reader with that song.
  void _openSongPicker(List<Song> songs, Song current, String bookName, Strings t) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _SongPickerSheet(
        songs: songs,
        currentId: current.id,
        bookName: bookName,
        title: t.songPickerTitle,
        hint: t.songPickerHint,
        countLabel: t.songPickerCount(songs.length),
        onPick: (s) {
          Navigator.of(context).pop();
          if (s.id != current.id) _go(s);
        },
      ),
    );
  }
}

class _SongPickerSheet extends StatefulWidget {
  final List<Song> songs;
  final String currentId;
  final String bookName;
  final String title;
  final String hint;
  final String countLabel;
  final void Function(Song) onPick;
  const _SongPickerSheet({
    required this.songs,
    required this.currentId,
    required this.bookName,
    required this.title,
    required this.hint,
    required this.countLabel,
    required this.onPick,
  });

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  final _ctrl = TextEditingController();
  late List<Song> _filtered = widget.songs;

  void _onQuery(String q) {
    final s = q.trim().toLowerCase();
    setState(() {
      _filtered = s.isEmpty
          ? widget.songs
          : widget.songs
              .where((song) =>
                  song.label.toLowerCase().startsWith(s) ||
                  song.displayTitle.toLowerCase().contains(s))
              .toList();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final maxH = MediaQuery.of(context).size.height * 0.78;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(widget.title,
                            style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
                      ),
                      Text(widget.countLabel,
                          style: TextStyle(
                              fontFamily: AppFonts.mono, fontSize: 11, color: reader.muted)),
                    ],
                  ),
                  Text(widget.bookName.toUpperCase(),
                      style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 10.5,
                          letterSpacing: 1.2,
                          color: reader.muted)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ctrl,
                    onChanged: _onQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('—',
                          style: TextStyle(color: reader.muted, fontFamily: AppFonts.mono)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final s = _filtered[i];
                        final sel = s.id == widget.currentId;
                        return ListTile(
                          dense: true,
                          selected: sel,
                          selectedTileColor:
                              theme.colorScheme.primary.withValues(alpha: 0.08),
                          leading: SizedBox(
                            width: 46,
                            child: Text('#${s.label}',
                                style: TextStyle(
                                    fontFamily: AppFonts.mono,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? theme.colorScheme.primary : reader.muted)),
                          ),
                          title: Text(s.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: AppFonts.uiBody,
                                  fontSize: 14.5,
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                  color: theme.colorScheme.onSurface)),
                          trailing: sel
                              ? Icon(Icons.check_rounded,
                                  size: 18, color: theme.colorScheme.primary)
                              : null,
                          onTap: () => widget.onPick(s),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String bookName;
  final bool isFav;
  final VoidCallback onBack;
  final VoidCallback onFav;
  final VoidCallback onDisplay;
  final VoidCallback onShare;
  const _TopBar({
    required this.bookName,
    required this.isFav,
    required this.onBack,
    required this.onFav,
    required this.onDisplay,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: reader.hairline)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: onBack),
              Expanded(
                child: Text(
                  bookName.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: reader.muted),
                ),
              ),
              _icon(isFav ? Icons.favorite : Icons.favorite_border, onFav,
                  color: isFav ? theme.colorScheme.primary : null),
              _icon(Icons.text_format_rounded, onDisplay),
              _icon(Icons.ios_share_rounded, onShare),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(IconData i, VoidCallback onTap, {Color? color}) => IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(i, size: 20, color: color),
        onPressed: onTap,
      );
}

class _BottomBar extends StatelessWidget {
  final String number;
  final String prevLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onPick;
  const _BottomBar(
      {required this.number,
      required this.prevLabel,
      required this.onPrev,
      required this.onNext,
      this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final muted = reader.muted;
    TextStyle st(bool on) => TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 12,
        letterSpacing: 0.5,
        color: on ? theme.colorScheme.onSurface.withValues(alpha: 0.8) : muted.withValues(alpha: 0.4));

    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: reader.hairline))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onPrev,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text('‹  Prev', style: st(onPrev != null)),
                    ),
                  ),
                ),
              ),
              // Tap the number to jump to another song in the same book.
              InkWell(
                onTap: onPick,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_note_rounded, size: 13, color: theme.colorScheme.primary),
                      const SizedBox(width: 5),
                      Text(number,
                          style: TextStyle(
                              fontFamily: AppFonts.mono, fontSize: 12, color: muted)),
                      if (onPick != null) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.unfold_more_rounded, size: 14, color: muted),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onNext,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text('Next  ›', style: st(onNext != null)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostingBanner extends StatelessWidget {
  final String liveLabel;
  final String followersLabel;
  final String stopLabel;
  final VoidCallback onStop;
  const _HostingBanner({
    required this.liveLabel,
    required this.followersLabel,
    required this.stopLabel,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      color: accent.withValues(alpha: 0.10),
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent)),
          const SizedBox(width: 8),
          Text(liveLabel,
              style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                  color: accent)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(followersLabel,
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, color: accent)),
          ),
          TextButton(
            onPressed: onStop,
            style: TextButton.styleFrom(foregroundColor: accent),
            child: Text(stopLabel, style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

/// A classic printed-hymnal end mark shown after the last stanza: a centered
/// rust label flanked by small diamonds and thin rules, so the reader can see
/// at a glance that the song is finished (and not keep scrolling for more).
class _EndOfSong extends StatelessWidget {
  final String label;
  const _EndOfSong({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ReaderPalette>()!;
    final accent = palette.chorusAccent;

    Widget rule() => Expanded(
          child: Container(height: 1.2, color: palette.muted.withValues(alpha: 0.45)),
        );
    Widget diamond() => Transform.rotate(
          angle: 0.7853981633974483, // 45°
          child: Container(width: 6, height: 6, color: accent),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          rule(),
          const SizedBox(width: 12),
          diamond(),
          const SizedBox(width: 11),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(width: 11),
          diamond(),
          const SizedBox(width: 12),
          rule(),
        ],
      ),
    );
  }
}

class _VariantSwitcher extends StatelessWidget {
  final Song current;
  final List<Song> variants;
  final String Function(String) label;
  const _VariantSwitcher(
      {required this.current, required this.variants, required this.label});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final v in variants)
          ChoiceChip(
            selected: v.id == current.id,
            label: Text(label(v.variant ?? '')),
            onSelected: v.id == current.id
                ? null
                : (_) => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => ReaderScreen(songId: v.id)),
                    ),
          ),
      ],
    );
  }
}
