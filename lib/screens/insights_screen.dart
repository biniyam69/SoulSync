import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/emotion.dart';
import '../models/intent.dart';
import '../models/memory_entry.dart';
import '../providers/intent_provider.dart';
import '../providers/people_provider.dart';
import '../providers/app_providers.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';

// Provider that loads the last 7 memories and generates a weekly insight
final _weekInsightProvider = FutureProvider<_InsightsData>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  final claude = ref.watch(claudeServiceProvider);

  await storage.init();
  final allMemories = await storage.loadAllMemories();
  final weekMemories = allMemories.take(7).toList();

  // Streak = consecutive days with sessions
  final dates = await storage.listSessionDates();
  int streak = 0;
  DateTime check = DateTime.now();
  for (int i = 0; i < dates.length && i < 30; i++) {
    final d = DateFormat('yyyy-MM-dd').format(check);
    if (dates.contains(d)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }

  // Mood arc from memories
  final moodArc = <String, EmotionalState>{};
  for (final m in weekMemories) {
    if (m.userMoods.isNotEmpty) {
      final dominant = EmotionalState.detectLocal(m.userMoods.join(' '));
      moodArc[m.date] = dominant;
    }
  }

  // Claude insight (only if we have memories)
  String? insight;
  if (weekMemories.isNotEmpty) {
    try {
      insight = await claude.generateWeeklyInsight(
        memories: weekMemories,
        recentEntries: [],
      );
    } catch (_) {}
  }

  return _InsightsData(
    weekMemories: weekMemories,
    moodArc: moodArc,
    streak: streak,
    insight: insight,
  );
});

class _InsightsData {
  final List<MemoryEntry> weekMemories;
  final Map<String, EmotionalState> moodArc;
  final int streak;
  final String? insight;

  const _InsightsData({
    required this.weekMemories,
    required this.moodArc,
    required this.streak,
    this.insight,
  });
}

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_weekInsightProvider);
    final intentsAsync = ref.watch(intentProvider);
    final peopleAsync = ref.watch(peopleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Insights',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: dataAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Text('Could not load insights',
              style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Streak tile
            _StreakTile(streak: data.streak),
            const SizedBox(height: 16),

            // Mood arc
            if (data.moodArc.isNotEmpty) ...[
              _MoodArcCard(moodArc: data.moodArc),
              const SizedBox(height: 16),
            ],

            // Intents stats
            intentsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (intents) => _IntentStatsCard(intents: intents),
            ),
            const SizedBox(height: 16),

            // People this week
            peopleAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (people) {
                final weekPeople = _weekPeople(data.weekMemories, people);
                if (weekPeople.isEmpty) return const SizedBox.shrink();
                return _PeopleChipsCard(
                  names: weekPeople,
                  onTap: () => Navigator.pushNamed(context, '/relationships'),
                );
              },
            ),
            const SizedBox(height: 16),

            // Claude insight
            if (data.insight != null) _InsightCard(text: data.insight!),

            if (data.weekMemories.isEmpty)
              _EmptyState(),
          ],
        ),
      ),
    );
  }

  List<String> _weekPeople(
      List<MemoryEntry> memories, List<dynamic> allPeople) {
    final names = <String>{};
    for (final m in memories) {
      names.addAll(m.keyPeople);
    }
    return names.take(10).toList();
  }
}

// ─── Streak ─────────────────────────────────────────────────────────────────

class _StreakTile extends StatelessWidget {
  final int streak;
  const _StreakTile({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.amber.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$streak day${streak == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amber,
                ),
              ),
              Text(
                'documenting your life',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Mood Arc ────────────────────────────────────────────────────────────────

class _MoodArcCard extends StatelessWidget {
  final Map<String, EmotionalState> moodArc;
  const _MoodArcCard({required this.moodArc});

  @override
  Widget build(BuildContext context) {
    final sortedKeys = moodArc.keys.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MOOD THIS WEEK',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: sortedKeys.map((date) {
              final mood = moodArc[date]!;
              final label = DateFormat('E').format(DateTime.parse(date));
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(mood.colorValue).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(mood.emoji,
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textTertiary),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Intent Stats ────────────────────────────────────────────────────────────

class _IntentStatsCard extends StatelessWidget {
  final List<Intent> intents;
  const _IntentStatsCard({required this.intents});

  @override
  Widget build(BuildContext context) {
    final open = intents.where((i) => i.isOpen).length;
    final done = intents.where((i) => i.isDone).length;
    final total = open + done;
    final pct = total == 0 ? 0.0 : done / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMITMENTS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatItem(value: '$open', label: 'open', color: AppColors.amber),
              const SizedBox(width: 24),
              _StatItem(
                  value: '$done',
                  label: 'done',
                  color: const Color(0xFF30D158)),
              const SizedBox(width: 24),
              _StatItem(
                  value: '${(pct * 100).round()}%',
                  label: 'completion',
                  color: AppColors.orbSpeaking),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF30D158)),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatItem(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─── People Chips ────────────────────────────────────────────────────────────

class _PeopleChipsCard extends StatelessWidget {
  final List<String> names;
  final VoidCallback? onTap;
  const _PeopleChipsCard({required this.names, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: const Border.fromBorderSide(
              BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'PEOPLE IN YOUR LIFE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.8,
                  ),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      size: 14, color: AppColors.textTertiary),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: names
                  .map((n) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.amberDim,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          n,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.amber,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Claude Insight ──────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final String text;
  const _InsightCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orbSpeaking.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.orbSpeaking.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: AppColors.orbSpeaking),
              const SizedBox(width: 6),
              Text(
                'WEEKLY INSIGHT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orbSpeaking,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded,
                color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              'Nothing to show yet',
              style: GoogleFonts.inter(
                  fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Start documenting your days. Insights will appear after your first nightly review.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textTertiary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
