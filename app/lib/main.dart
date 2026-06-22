import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/state/settings.dart';
import 'src/theme/app_theme.dart';
import 'src/ui/root_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const IndirimboApp(),
    ),
  );
}

class IndirimboApp extends ConsumerWidget {
  const IndirimboApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final uiFont = ref.watch(settingsProvider.select((s) => s.appFont));
    final textScale = ref.watch(settingsProvider.select((s) => s.appTextScale));
    // Keep inline `AppFonts.uiBody` styles across the UI in sync with the choice
    // (the theme covers themed text; this covers the many inline TextStyles).
    AppFonts.uiBody = uiFont;
    return MaterialApp(
      title: 'Indirimbo Zikundwa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(mode, uiFont: uiFont),
      // Apply the user's app-wide text size to every screen. Song lyrics opt out
      // of this in the reader (they have their own size control). Icons follow
      // the same scale via applyTextScaling, so they grow with the text.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: IconTheme.merge(
          data: const IconThemeData(applyTextScaling: true),
          child: child!,
        ),
      ),
      home: const RootShell(),
    );
  }
}
