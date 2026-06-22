import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import '../state/share_state.dart';
import '../state/strings.dart';
import '../theme/app_theme.dart';
import '../theme/font_combos.dart';
import 'about_sheet.dart';
import 'share_sheet.dart';
import 'widgets/reader_controls.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final t = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final session = ref.watch(shareControllerProvider);
    final repo = ref.watch(repositoryProvider).requireValue;
    final total = repo.collections.fold<int>(0, (a, c) => a + c.songCount);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Text(t.navSettings, style: theme.textTheme.titleLarge?.copyWith(fontSize: 24)),
            const SizedBox(height: 22),

            // Language
            _sectionLabel(context, reader, t.languageSection),
            const SizedBox(height: 10),
            _card(
              theme,
              reader,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final l in AppLanguage.values)
                    ChoiceChip(
                      selected: settings.language == l,
                      onSelected: (_) => ctrl.setLanguage(l),
                      label: Text(l.label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Library layout
            _sectionLabel(context, reader, t.layoutSection),
            const SizedBox(height: 10),
            _card(
              theme,
              reader,
              child: Row(
                children: [
                  Expanded(
                    child: _layoutOption(
                      theme, reader,
                      icon: Icons.grid_view_rounded,
                      label: t.layoutGrid,
                      selected: settings.libraryLayout == LibraryLayout.grid,
                      onTap: () => ctrl.setLibraryLayout(LibraryLayout.grid),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _layoutOption(
                      theme, reader,
                      icon: Icons.view_agenda_outlined,
                      label: t.layoutList,
                      selected: settings.libraryLayout == LibraryLayout.list,
                      onTap: () => ctrl.setLibraryLayout(LibraryLayout.list),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Live share
            _sectionLabel(context, reader, t.shareTitle),
            const SizedBox(height: 10),
            _shareCard(context, theme, reader, t, session),
            const SizedBox(height: 22),

            // Font pairing
            _sectionLabel(context, reader, t.fontComboSection),
            const SizedBox(height: 10),
            _card(
              theme,
              reader,
              child: Column(
                children: [
                  for (var i = 0; i < fontCombos.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: reader.hairline),
                    _comboRow(theme, reader, fontCombos[i], i == settings.fontCombo,
                        () => ctrl.setFontCombo(i)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),

            // App text (global font + size for the whole UI)
            _sectionLabel(context, reader, t.appTextSection),
            const SizedBox(height: 10),
            _card(theme, reader, child: _appTextControls(theme, reader, t, settings, ctrl)),
            const SizedBox(height: 22),

            // Reading display
            _sectionLabel(context, reader, t.display),
            const SizedBox(height: 10),
            _card(theme, reader, child: const ReaderControls()),
            const SizedBox(height: 16),
            _card(
              theme,
              reader,
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.keepScreenOn,
                                style: TextStyle(
                                    fontFamily: AppFonts.uiBody, fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(t.keepScreenOnHint,
                                style: TextStyle(
                                    fontFamily: AppFonts.uiBody, fontSize: 12.5, color: reader.muted)),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.keepScreenOn,
                        onChanged: (v) => ctrl.setKeepScreenOn(v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.touch_app_outlined, color: reader.muted, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(t.fullscreenHint,
                            style: TextStyle(
                                fontFamily: AppFonts.uiBody, fontSize: 12.5, height: 1.4, color: reader.muted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _infoTile(theme, reader,
                icon: Icons.menu_book_outlined,
                title: t.libraryTile,
                subtitle: t.libraryDesc(total, repo.collections.length)),
            const SizedBox(height: 4),
            _infoTile(theme, reader,
                icon: Icons.info_outline,
                title: t.aboutTile,
                subtitle: t.aboutDesc,
                onTap: () => showAboutSheet(context),
                trailing: Icon(Icons.chevron_right_rounded, color: reader.muted)),
          ],
        ),
      ),
    );
  }

  Widget _shareCard(BuildContext context, ThemeData theme, ReaderPalette reader,
      Strings t, ShareSession session) {
    final accent = theme.colorScheme.primary;
    String status;
    Color statusColor = reader.muted;
    if (session.isHosting) {
      status = '${t.shareLiveBadge} · ${t.shareFollowers(session.followers)}';
      statusColor = accent;
    } else if (session.isFollowing) {
      status = t.shareFollowingTitle(session.sessionName ?? '');
      statusColor = accent;
    } else {
      status = t.shareSubtitle;
    }
    final active = session.isHosting || session.isFollowing;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showShareSheet(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: active ? accent.withValues(alpha: 0.45) : reader.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(active ? Icons.podcasts_rounded : Icons.podcasts_outlined,
                    color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.shareTitle,
                        style: TextStyle(
                            fontFamily: AppFonts.uiBody, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppFonts.uiBody, fontSize: 12.5, color: statusColor)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: reader.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _comboRow(ThemeData theme, ReaderPalette reader, FontCombo combo, bool selected,
      VoidCallback onTap) {
    final accent = theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title preview in the combo's title font.
                  Text('Cantique',
                      style: combo.titleStyle(null,
                          fontSize: 21, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 2),
                  // Lyrics preview in the combo's lyrics font.
                  Text('Béni soit le lien qui unit nos cœurs.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: combo.lyrics, fontSize: 13.5, color: reader.verseText)),
                  const SizedBox(height: 4),
                  Text(combo.name.toUpperCase(),
                      style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 9,
                          letterSpacing: 0.8,
                          color: reader.muted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? accent : reader.muted.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _appTextControls(ThemeData theme, ReaderPalette reader, Strings t,
      ReaderSettings settings, SettingsController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.appTextHint,
            style: TextStyle(
                fontFamily: AppFonts.uiBody, fontSize: 12.5, height: 1.4, color: reader.muted)),
        const SizedBox(height: 16),
        Text(t.fontSection.toUpperCase(),
            style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: reader.muted)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in readerFonts)
              ChoiceChip(
                selected: settings.appFont == f,
                onSelected: (_) => ctrl.setAppFont(f),
                label: Text(f, style: TextStyle(fontFamily: f, fontSize: 13)),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Icon(Icons.format_size_rounded, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(t.textSize,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppFonts.uiBody, fontSize: 15)),
            ),
            IconButton.filledTonal(
                onPressed: () => ctrl.setAppTextScale(settings.appTextScale - 0.05),
                icon: const Icon(Icons.remove),
                iconSize: 18),
            SizedBox(
              width: 58,
              child: Text('${(settings.appTextScale * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppFonts.uiBody, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            IconButton.filledTonal(
                onPressed: () => ctrl.setAppTextScale(settings.appTextScale + 0.05),
                icon: const Icon(Icons.add),
                iconSize: 18),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: ctrl.isAppTextDefault ? null : ctrl.resetAppText,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: Text(t.resetDefaults),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              textStyle: TextStyle(fontFamily: AppFonts.uiBody, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, ReaderPalette reader, String text) =>
      Text(text.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10.5,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: reader.muted,
          ));

  Widget _card(ThemeData theme, ReaderPalette reader, {required Widget child}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: reader.hairline),
        ),
        child: child,
      );

  Widget _layoutOption(ThemeData theme, ReaderPalette reader,
      {required IconData icon,
      required String label,
      required bool selected,
      required VoidCallback onTap}) {
    final accent = theme.colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? accent.withValues(alpha: 0.5) : reader.hairline),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? accent : reader.muted),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontFamily: AppFonts.uiBody,
                    fontWeight: FontWeight.w600,
                    color: selected ? accent : theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(ThemeData theme, ReaderPalette reader,
      {required IconData icon,
      required String title,
      required String subtitle,
      VoidCallback? onTap,
      Widget? trailing}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title,
          style: TextStyle(fontFamily: AppFonts.uiBody, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(fontFamily: AppFonts.uiBody, color: reader.muted, fontSize: 13)),
      trailing: trailing,
    );
  }
}
