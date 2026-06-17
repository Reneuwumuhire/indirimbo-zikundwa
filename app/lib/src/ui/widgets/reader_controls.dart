import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/font_combos.dart';

/// Reusable controls for theme, font, size and line spacing.
class ReaderControls extends ConsumerWidget {
  const ReaderControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final t = ref.watch(stringsProvider);
    final combo = ref.watch(fontComboProvider);
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(context, t.themeSection),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final m in AppThemeMode.values)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  selected: s.themeMode == m,
                  onSelected: (_) => ctrl.setTheme(m),
                  avatar: Icon(m.icon, size: 18,
                      color: s.themeMode == m ? theme.colorScheme.primary : reader.muted),
                  label: Text(t.themeModeName(m)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        _stepper(context,
            icon: Icons.format_size_rounded,
            label: t.textSize,
            value: '${s.fontSize.round()}',
            onMinus: () => ctrl.setFontSize(s.fontSize - 1),
            onPlus: () => ctrl.setFontSize(s.fontSize + 1)),
        const SizedBox(height: 14),
        _stepper(context,
            icon: Icons.format_line_spacing_rounded,
            label: t.lineSpacing,
            value: s.lineHeight.toStringAsFixed(1),
            onMinus: () => ctrl.setLineHeight(s.lineHeight - 0.1),
            onPlus: () => ctrl.setLineHeight(s.lineHeight + 0.1)),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: reader.page,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: reader.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cantique',
                  style: combo.titleStyle(null, fontSize: 22, color: reader.verseText)),
              const SizedBox(height: 8),
              Text(
                t.sample,
                style: TextStyle(
                  fontFamily: combo.lyrics,
                  fontSize: s.fontSize,
                  height: s.lineHeight,
                  color: reader.verseText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String t) => Text(
        t.toUpperCase(),
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10.5,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).extension<ReaderPalette>()!.muted,
        ),
      );

  Widget _stepper(BuildContext context,
      {required IconData icon,
      required String label,
      required String value,
      required VoidCallback onMinus,
      required VoidCallback onPlus}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontFamily: AppFonts.body, fontSize: 15)),
        const Spacer(),
        IconButton.filledTonal(onPressed: onMinus, icon: const Icon(Icons.remove), iconSize: 18),
        SizedBox(
            width: 46,
            child: Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: AppFonts.body, fontWeight: FontWeight.w700, fontSize: 15))),
        IconButton.filledTonal(onPressed: onPlus, icon: const Icon(Icons.add), iconSize: 18),
      ],
    );
  }
}
