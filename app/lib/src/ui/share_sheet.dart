import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../share/song_share.dart';
import '../share/transport.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../state/share_state.dart';
import '../theme/app_theme.dart';
import '../theme/font_combos.dart';

const _taupe = Color(0xFF9C8C76);

/// Opens the live-share bottom sheet. Pass the song being read so hosting starts
/// on it; from Settings hosting falls back to the first song.
Future<void> showShareSheet(BuildContext context, [String? currentSongId]) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ShareSheet(currentSongId: currentSongId),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  final String? currentSongId;
  const _ShareSheet({required this.currentSongId});
  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

enum _Mode { menu, join }

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  _Mode _mode = _Mode.menu;
  final _name = TextEditingController();
  final _addr = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _addr.dispose();
    super.dispose();
  }

  Song? _song() {
    final repo = ref.read(repositoryProvider).valueOrNull;
    if (repo == null) return null;
    final id = widget.currentSongId;
    if (id != null) return repo.byId(id);
    for (final c in repo.collections) {
      final s = repo.songsIn(c.id);
      if (s.isNotEmpty) return s.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ref.watch(stringsProvider);
    final session = ref.watch(shareControllerProvider);
    final canHost = ref.watch(canHostProvider);
    final song = _song();
    final repo = ref.read(repositoryProvider).valueOrNull;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.ios_share_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(t.shareTitle, style: theme.textTheme.titleLarge?.copyWith(fontSize: 19))),
              IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20)),
            ],
          ),
          const SizedBox(height: 8),
          if (session.isHosting)
            _hosting(theme, t, session, song, repo)
          else if (_mode == _Mode.join)
            _join(theme, t)
          else
            _menu(theme, t, canHost, song, repo),
        ],
      ),
    );
  }

  Widget _nowSinging(ThemeData theme, dynamic t, Song? song, repo) {
    if (song == null) return const SizedBox.shrink();
    final collname = repo?.collection(song.series).name ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.spineOf(theme.colorScheme.surface).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.extension<ReaderPalette>()!.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(theme, 'NOW SINGING'),
          const SizedBox(height: 8),
          Text('#${song.label} — ${song.displayTitle}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ref
                  .watch(fontComboProvider)
                  .titleStyle(null, fontSize: 16, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 3),
          Text(collname,
              style: TextStyle(
                  fontFamily: AppFonts.uiBody,
                  fontStyle: FontStyle.italic,
                  fontSize: 13.5,
                  color: theme.extension<ReaderPalette>()!.muted)),
        ],
      ),
    );
  }

  Widget _menu(ThemeData theme, dynamic t, bool canHost, Song? song, repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _nowSinging(theme, t, song, repo),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _ShareCtaButton(
            label: t.shareAsText,
            icon: Icons.ios_share_rounded,
            enabled: song != null,
            onTap: song == null
                ? null
                : () {
                    final name = repo?.collection(song.series).name ?? '';
                    Navigator.of(context).pop();
                    shareSong(song, name, t);
                  },
          ),
        ),
        const SizedBox(height: 18),
        _label(theme, t.shareLiveSectionHint.toUpperCase()),
        const SizedBox(height: 12),
        if (canHost) ...[
          _label(theme, t.shareHostHint.toUpperCase()),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: _input(theme, 'e.g. Sister Maria'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _ShareCtaButton(
              label: t.shareHostAction,
              enabled: song != null,
              onTap: song == null ? null : () => _host(song),
            ),
          ),
          const SizedBox(height: 14),
        ] else ...[
          _info(theme, t.shareHostUnavailableWeb),
          const SizedBox(height: 8),
        ],
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _mode = _Mode.join),
            icon: Icon(Icons.cell_tower_rounded, size: 18, color: theme.colorScheme.primary),
            label: Text(t.shareJoinAction,
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12.5, color: theme.colorScheme.primary)),
          ),
        ),
      ],
    );
  }

  Widget _hosting(ThemeData theme, dynamic t, ShareSession session, Song? song, repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _nowSinging(theme, t, song, repo),
        if (session.joinUrls.isNotEmpty) ...[
          const SizedBox(height: 18),
          _label(theme, 'SHARE LINK'),
          const SizedBox(height: 8),
          ...session.joinUrls.take(2).map((u) => _CopyRow(url: u, copied: t.shareCopied)),
          const SizedBox(height: 2),
          Text(t.shareLinkBrowserHint,
              style: TextStyle(
                  fontFamily: AppFonts.uiBody,
                  fontSize: 12,
                  height: 1.35,
                  color: theme.extension<ReaderPalette>()!.muted)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.groups_outlined, size: 16, color: theme.extension<ReaderPalette>()!.muted),
            const SizedBox(width: 8),
            Text(
              session.followers == 0 ? 'No activity yet' : t.shareFollowers(session.followers),
              style: TextStyle(
                  fontFamily: AppFonts.mono, fontSize: 12, color: theme.extension<ReaderPalette>()!.muted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await ref.read(shareControllerProvider.notifier).leave();
              if (mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: Text(t.shareStop, style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 12.5)),
          ),
        ),
      ],
    );
  }

  Widget _join(ThemeData theme, dynamic t) {
    final sessions = ref.watch(discoveryProvider).valueOrNull ?? const <DiscoveredSession>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
                onPressed: () => setState(() => _mode = _Mode.menu),
                icon: const Icon(Icons.arrow_back_rounded, size: 20)),
            Text(t.shareJoinAction.toUpperCase(),
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, letterSpacing: 1, color: theme.extension<ReaderPalette>()!.muted)),
          ],
        ),
        ...sessions.map((s) => _SessionTile(
              session: s,
              onTap: () async {
                await ref.read(shareControllerProvider.notifier).joinSession(s);
                if (mounted) Navigator.of(context).pop();
              },
            )),
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text(t.shareSearching,
                  style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11.5, color: theme.extension<ReaderPalette>()!.muted)),
            ]),
          ),
        const SizedBox(height: 10),
        _label(theme, t.shareJoinByAddress.toUpperCase()),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _addr,
              decoration: _input(theme, t.shareAddressHint),
              onSubmitted: (_) => _connectManual(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _taupe, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: _connectManual,
            child: Text(t.shareConnect, style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 12)),
          ),
        ]),
      ],
    );
  }

  Future<void> _host(Song song) async {
    final name = _name.text.trim();
    await ref.read(shareControllerProvider.notifier).startHosting(
          SharedView(songId: song.id),
          name: name.isEmpty ? 'Indirimbo · ${_shortCode()}' : name,
        );
  }

  Future<void> _connectManual() async {
    final text = _addr.text.trim();
    if (text.isEmpty) return;
    await ref.read(shareControllerProvider.notifier).joinByAddress(text);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _label(ThemeData theme, String s) => Text(s,
      style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: theme.extension<ReaderPalette>()!.muted));

  InputDecoration _input(ThemeData theme, String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        hintStyle: TextStyle(fontFamily: AppFonts.uiBody, color: theme.extension<ReaderPalette>()!.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.extension<ReaderPalette>()!.hairline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colorScheme.primary)),
      );

  Widget _info(ThemeData theme, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.extension<ReaderPalette>()!.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontFamily: AppFonts.uiBody, fontSize: 13.5, height: 1.4, color: theme.extension<ReaderPalette>()!.verseText)),
          ),
        ],
      );

  String _shortCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final n = DateTime.now().microsecondsSinceEpoch;
    return List.generate(4, (i) => chars[(n >> (i * 5)) % chars.length]).join();
  }
}

/// Primary "share my view" call-to-action: brand-gradient fill, drop shadow and
/// an icon so it reads unmistakably as a tappable button (the old flat taupe fill
/// looked disabled).
class _ShareCtaButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final IconData icon;
  const _ShareCtaButton(
      {required this.label,
      required this.enabled,
      this.onTap,
      this.icon = Icons.podcasts_rounded});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: radius,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppTheme.rust.withValues(alpha: 0.38),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(label,
                      style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final DiscoveredSession session;
  final VoidCallback onTap;
  const _SessionTile({required this.session, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        child: Row(children: [
          Icon(Icons.podcasts_rounded, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.name,
                  style: const TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700, fontSize: 15)),
              Text(session.host, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: reader.muted)),
            ]),
          ),
          Icon(Icons.login_rounded, size: 18, color: reader.muted),
        ]),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String url;
  final String copied;
  const _CopyRow({required this.url, required this.copied});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: reader.hairline)),
        child: Row(children: [
          Expanded(
            child: Text(url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: reader.verseText)),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(copied), duration: const Duration(seconds: 1)));
            },
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: Text(copied == 'Copié' ? 'Copier' : 'Copy',
                style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 11)),
          ),
        ]),
      ),
    );
  }
}
