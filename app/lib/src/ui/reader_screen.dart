import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../share/transport.dart';
import '../state/favorites.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../state/share_state.dart';
import '../theme/app_theme.dart';
import '../theme/font_combos.dart';
import 'share_sheet.dart';
import 'widgets/lyrics_viewer.dart';
import 'widgets/reader_controls.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String songId;
  const ReaderScreen({super.key, required this.songId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _scroll = ScrollController();
  DateTime _lastBroadcast = DateTime.fromMillisecondsSinceEpoch(0);

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
    super.dispose();
  }

  void _onScroll() => _broadcast();

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

  void _go(Song s) => Navigator.of(context)
      .pushReplacement(MaterialPageRoute(builder: (_) => ReaderScreen(songId: s.id)));

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

    ref.listen(shareControllerProvider.select((s) => s.isHosting), (_, hosting) {
      if (hosting) _broadcast(force: true);
    });

    final inSeries = repo.songsIn(song.series);
    final pos = inSeries.indexWhere((s) => s.id == song.id);
    final prev = pos > 0 ? inSeries[pos - 1] : null;
    final next = (pos >= 0 && pos < inSeries.length - 1) ? inSeries[pos + 1] : null;

    final variants = repo
        .songsIn(song.series)
        .where((s) => s.number == song.number && s.variant != null)
        .toList();

    return Scaffold(
      backgroundColor: palette.page,
      body: Column(
        children: [
          _TopBar(
            bookName: collection.name,
            isFav: isFav,
            onBack: () => Navigator.of(context).maybePop(),
            onFav: () => ref.read(favoritesProvider.notifier).toggle(song.id),
            onDisplay: () => _openDisplaySheet(context, t.display),
            onShare: () => showShareSheet(context, song.id),
          ),
          if (session.isHosting)
            _HostingBanner(
              liveLabel: t.shareLiveBadge,
              followersLabel: t.shareFollowers(session.followers),
              stopLabel: t.shareStop,
              onStop: () => ref.read(shareControllerProvider.notifier).leave(),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
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
                        fontSize: (settings.fontSize + 9).clamp(24, 44),
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
                    LyricsViewer(song: song, settings: settings),
                  ],
                ),
              ),
            ),
          ),
          _BottomBar(
            number: song.label,
            prevLabel: t.shareBack,
            onPrev: prev == null ? null : () => _go(prev),
            onNext: next == null ? null : () => _go(next),
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
  const _BottomBar(
      {required this.number, required this.prevLabel, required this.onPrev, required this.onNext});

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_note_rounded, size: 13, color: theme.colorScheme.primary),
                  const SizedBox(width: 5),
                  Text(number,
                      style: TextStyle(
                          fontFamily: AppFonts.mono, fontSize: 12, color: muted)),
                ],
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
