import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'models/morning_briefing.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/nightly_review_screen.dart';
import 'screens/memory_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/intents_screen.dart';
import 'screens/thought_journal_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/relationships_screen.dart';
import 'screens/introspection_screen.dart';
import 'screens/morning_briefing_screen.dart';

import 'screens/weekly_digest_screen.dart';

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
        '/intents': (_) => const IntentsScreen(),
        '/thought-journal': (_) => const ThoughtJournalScreen(),
        '/insights': (_) => const InsightsScreen(),
        '/relationships': (_) => const RelationshipsScreen(),
        '/introspection': (_) => const IntrospectionScreen(),
        '/weekly-digest': (_) => const WeeklyDigestScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/morning-briefing') {
          final briefing = settings.arguments as MorningBriefing;
          return MaterialPageRoute(
            builder: (_) => MorningBriefingScreen(briefing: briefing),
          );
        }
        return null;
      },
    );
  }
}
