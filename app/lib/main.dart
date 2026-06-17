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
    return MaterialApp(
      title: 'Indirimbo Zikundwa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(mode),
      home: const RootShell(),
    );
  }
}
