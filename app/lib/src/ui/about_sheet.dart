import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/settings.dart';
import '../theme/app_theme.dart';

const _siteUrl = 'https://www.missionnaire.net/';

/// Opens the "About" sheet — explains the app, the public-domain hymn sources,
/// and the missionnaire.net ministry (with a link).
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
                    fontFamily: AppFonts.body, fontSize: 15, height: 1.5, color: reader.verseText)),
            const SizedBox(height: 10),
            Text(t.aboutSourceNote,
                style: TextStyle(
                    fontFamily: AppFonts.body, fontSize: 13, height: 1.45, color: reader.muted)),
            const SizedBox(height: 20),
            Divider(color: reader.hairline),
            const SizedBox(height: 16),
            Text(t.aboutSiteTitle,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 17)),
            const SizedBox(height: 8),
            Text(t.aboutSiteBody,
                style: TextStyle(
                    fontFamily: AppFonts.body, fontSize: 14.5, height: 1.5, color: reader.verseText)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _open(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(t.visitSite,
                    style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('missionnaire.net',
                  style: TextStyle(
                      fontFamily: AppFonts.mono, fontSize: 11, letterSpacing: 0.5, color: reader.muted)),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text('Indirimbo Zikundwa · v1.0.0',
                  style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: reader.muted)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(_siteUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) await launchUrl(uri);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(_siteUrl)),
        );
      }
    }
  }
}
