import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/intent.dart';
import '../providers/intent_provider.dart';

class IntentsScreen extends ConsumerWidget {
  const IntentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intentsAsync = ref.watch(intentProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Commitments',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: intentsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        data: (intents) {
          final open =
              intents.where((i) => i.status == IntentStatus.open).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final done =
              intents.where((i) => i.status == IntentStatus.done).toList()
                ..sort((a, b) =>
                    (b.completedAt ?? b.createdAt)
                        .compareTo(a.completedAt ?? a.createdAt));

          if (intents.isEmpty) return _EmptyState();

          return CustomScrollView(
            slivers: [
              if (open.isNotEmpty) ...[
                _SectionHeader(
                    title: 'OPEN',
                    count: open.length,
                    color: AppColors.amber),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _IntentTile(
                      intent: open[i],
                      onDone: () =>
                          ref.read(intentProvider.notifier).markDone(open[i].id),
                      onDismiss: () => ref
                          .read(intentProvider.notifier)
                          .dismiss(open[i].id),
                    ),
                    childCount: open.length,
                  ),
                ),
              ],
              if (done.isNotEmpty) ...[
                _SectionHeader(
                    title: 'COMPLETED',
                    count: done.length,
                    color: AppColors.textTertiary),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _IntentTile(
                      intent: done[i],
                      onDone: null,
                      onDismiss: () => ref
                          .read(intentProvider.notifier)
                          .deleteIntent(done[i].id),
                      isDone: true,
                    ),
                    childCount: done.length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader(
      {required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentTile extends StatelessWidget {
  final Intent intent;
  final VoidCallback? onDone;
  final VoidCallback onDismiss;
  final bool isDone;

  const _IntentTile({
    required this.intent,
    required this.onDone,
    required this.onDismiss,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(intent.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withOpacity(0.15),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) => onDismiss(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.fromBorderSide(
              BorderSide(
                color: isDone
                    ? AppColors.border
                    : intent.ageDays >= 3
                        ? Colors.redAccent.withOpacity(0.3)
                        : AppColors.border,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isDone)
                GestureDetector(
                  onTap: onDone,
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 12, top: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.amber, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                )
              else
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 12, top: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D158).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 14, color: Color(0xFF30D158)),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intent.text,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDone
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                        decoration: isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatAge(intent),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: intent.ageDays >= 3 && !isDone
                                ? Colors.redAccent.withOpacity(0.8)
                                : AppColors.textTertiary,
                          ),
                        ),
                        if (intent.rawText.isNotEmpty &&
                            intent.rawText != intent.text) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '"${intent.rawText}"',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAge(Intent intent) {
    if (intent.isDone && intent.completedAt != null) {
      return 'Completed ${DateFormat('MMM d').format(intent.completedAt!)}';
    }
    if (intent.ageDays == 0) return 'Today';
    if (intent.ageDays == 1) return 'Yesterday';
    return '${intent.ageDays} days ago';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              'No commitments yet',
              style: GoogleFonts.inter(
                  fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Say things like "I should..." or "I need to..." and I\'ll track them for you.',
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
