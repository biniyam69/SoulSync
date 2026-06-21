import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/nightly_review_screen.dart';
import 'screens/memory_screen.dart';
import 'screens/settings_screen.dart';

class SoulSyncApp extends ConsumerWidget {
  const SoulSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingDone = ref.watch(onboardingDoneProvider);

    return MaterialApp(
      title: 'SoulSync',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      initialRoute: onboardingDone ? '/home' : '/onboarding',
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/home': (_) => const HomeScreen(),
        '/review': (_) => const NightlyReviewScreen(),
        '/memory': (_) => const MemoryScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
