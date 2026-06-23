import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:indirimbo/src/state/settings.dart';
import 'package:indirimbo/src/core/app_theme.dart';

/// Opens the "About" sheet. Indirimbo Zikundwa is an independent, offline
/// hymnal reader — not affiliated with any organization.
Future<void> showAboutSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => const _AboutSheet(),
  );
}

class _AboutSheet extends ConsumerWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final t = ref.watch(stringsProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 4, 22, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(width: 4, height: 26, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Indirimbo Zikundwa',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 22)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(t.aboutAppBody,
                style: TextStyle(
                    fontFamily: AppFonts.uiBody, fontSize: 15, height: 1.5, color: reader.verseText)),
            const SizedBox(height: 12),
            Text(t.aboutSourceNote,
                style: TextStyle(
                    fontFamily: AppFonts.uiBody, fontSize: 13, height: 1.45, color: reader.muted)),
            const SizedBox(height: 24),
            Center(
              child: Text('Indirimbo Zikundwa · v1.0.0',
                  style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: reader.muted)),
            ),
          ],
        ),
      ),
    );
  }
}
