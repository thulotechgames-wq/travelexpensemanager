import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'data/storage.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final storage = await Storage.open();
  runApp(ProviderScope(
    overrides: [storageProvider.overrideWithValue(storage)],
    child: const TravelExpensesApp(),
  ));
}

class TravelExpensesApp extends ConsumerWidget {
  const TravelExpensesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'Travel Expenses Manager',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: settings.onboarded
            ? const HomeScreen(key: ValueKey('home'))
            : const OnboardingScreen(key: ValueKey('onboarding')),
      ),
    );
  }
}
