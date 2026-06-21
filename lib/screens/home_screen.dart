import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../providers/soul_provider.dart';
import '../providers/intent_provider.dart';
import '../providers/morning_briefing_provider.dart';
import '../providers/persona_provider.dart';
import '../widgets/soul_orb.dart';
import '../widgets/transcript_tile.dart';
import '../widgets/waveform_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(soulProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final soul = ref.watch(soulProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            Text(
              'SoulSync',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            _StatusDot(phase: soul.phase, isListening: soul.isListening),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Insights',
            onPressed: () => Navigator.pushNamed(context, '/insights'),
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Thought Journal',
            onPressed: () => Navigator.pushNamed(context, '/thought-journal'),
          ),
          IconButton(
            icon: const Icon(Icons.nightlight_round_outlined,
                color: AppColors.textSecondary),
            tooltip: 'Nightly Review',
            onPressed: () => Navigator.pushNamed(context, '/review'),
          ),
          IconButton(
            icon: const Icon(Icons.auto_stories_outlined,
                color: AppColors.textSecondary),
            tooltip: 'Memory',
            onPressed: () => Navigator.pushNamed(context, '/memory'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textSecondary),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Error banner
          if (soul.error != null)
            _ErrorBanner(
              error: soul.error!,
              onDismiss: () => ref.read(soulProvider.notifier).clearError(),
            ),

          // Main content
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Morning briefing card
                SliverToBoxAdapter(
                  child: _MorningBriefingCard(),
                ),

                // Orb section
                SliverToBoxAdapter(
                  child: _OrbSection(soul: soul),
                ),

                // Open intents chip
                SliverToBoxAdapter(
                  child: _OpenIntentsChip(),
                ),

                // Partial transcript (live)
                if (soul.partialText.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _PartialTranscript(text: soul.partialText),
                  ),

                // Assistant message
                if (soul.assistantMessage != null)
                  SliverToBoxAdapter(
                    child: _AssistantBubble(
                        message: soul.assistantMessage!),
                  ),

                // Today's transcript
                if (soul.session.entries.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Today',
                      trailing: _entryCount(soul.session.entries.length),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final entries =
                            soul.session.entries.reversed.toList();
                        return TranscriptTile(
                          entry: entries[i],
                        );
                      },
                      childCount: soul.session.entries.length,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ] else
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(isListening: soul.isListening),
                  ),
              ],
            ),
          ),
        ],
      ),

      // Floating listen button
      floatingActionButton: _ListenFab(
        soul: soul,
        onToggle: () {
          if (soul.isListening) {
            ref.read(soulProvider.notifier).stopListening();
          } else {
            ref.read(soulProvider.notifier).startListening();
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String _entryCount(int n) => '$n ${n == 1 ? 'entry' : 'entries'}';
}

// ─── Orb Section ──────────────────────────────────────────────────────────

class _OrbSection extends ConsumerWidget {
  final SoulState soul;
  const _OrbSection({required this.soul});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(personaProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          SoulOrb(
            phase: soul.phase,
            soundLevel: soul.soundLevel,
            size: 200,
          ),
          const SizedBox(height: 20),
          Text(
            _phaseLabel(soul.phase),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          // Persona badge
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/settings'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: const Border.fromBorderSide(
                    BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Text(
                '${persona.icon} ${persona.label}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          if (soul.nextCheckinAt != null && soul.isListening) ...[
            const SizedBox(height: 4),
            Text(
              'Next check-in ~${_formatCheckinTime(soul.nextCheckinAt!)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
          if (soul.isListening) ...[
            const SizedBox(height: 12),
            WaveformWidget(
              soundLevel: soul.soundLevel,
              color: _orbColor(soul.phase),
              barCount: 7,
              height: 32,
            ),
          ],
        ],
      ),
    );
  }

  String _phaseLabel(AppPhase phase) {
    switch (phase) {
      case AppPhase.idle:
        return 'TAP TO BEGIN';
      case AppPhase.listening:
        return 'LISTENING';
      case AppPhase.checkin:
        return 'CHECKING IN';
      case AppPhase.speaking:
        return 'SPEAKING';
      case AppPhase.nightlyReview:
        return 'NIGHTLY REVIEW';
    }
  }

  Color _orbColor(AppPhase phase) {
    if (phase == AppPhase.speaking || phase == AppPhase.checkin) {
      return AppColors.orbSpeaking;
    }
    return AppColors.amber;
  }

  String _formatCheckinTime(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inMinutes <= 1) return '1 min';
    return '${diff.inMinutes} min';
  }
}

// ─── Partial transcript live display ─────────────────────────────────────

class _PartialTranscript extends StatelessWidget {
  final String text;
  const _PartialTranscript({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.amberDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.amber.withOpacity(0.2), width: 0.5),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

// ─── Assistant message bubble ─────────────────────────────────────────────

class _AssistantBubble extends StatelessWidget {
  final String message;
  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.orbSpeaking.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppColors.orbSpeaking),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.orbSpeaking.withOpacity(0.07),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border.all(
                    color: AppColors.orbSpeaking.withOpacity(0.2), width: 0.5),
              ),
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(
              trailing!,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isListening;
  const _EmptyState({required this.isListening});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          isListening
              ? 'Listening... conversations will appear here.'
              : 'Tap the button below to start listening.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textTertiary,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

// ─── Floating Action Button ────────────────────────────────────────────────

class _ListenFab extends StatelessWidget {
  final SoulState soul;
  final VoidCallback onToggle;

  const _ListenFab({required this.soul, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isListening = soul.isListening;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: FloatingActionButton.extended(
        onPressed: onToggle,
        backgroundColor: isListening ? AppColors.surfaceElevated : AppColors.amber,
        elevation: 0,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 28),
        icon: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_rounded,
          color: isListening ? AppColors.textPrimary : Colors.black,
          size: 20,
        ),
        label: Text(
          isListening ? 'Stop Listening' : 'Start Listening',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isListening ? AppColors.textPrimary : Colors.black,
          ),
        ),
      ),
    );
  }
}

// ─── Status Dot ────────────────────────────────────────────────────────────

class _StatusDot extends StatefulWidget {
  final AppPhase phase;
  final bool isListening;
  const _StatusDot({required this.phase, required this.isListening});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isListening) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.isListening && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isListening) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isListening) {
      return Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.textTertiary,
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.amber.withOpacity(0.5 + _ctrl.value * 0.5),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Morning Briefing Card ────────────────────────────────────────────────

class _MorningBriefingCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingAsync = ref.watch(morningBriefingProvider);
    final notifier = ref.read(morningBriefingProvider.notifier);

    return briefingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (briefing) {
        if (briefing == null || !notifier.shouldShow) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/morning-briefing',
                arguments: briefing,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.amber.withOpacity(0.3), width: 0.5),
              ),
              child: Row(
                children: [
                  const Text('☀️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Morning Briefing',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.amber,
                          ),
                        ),
                        Text(
                          'Tap to hear your daily briefing',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textTertiary),
                    onPressed: () =>
                        ref.read(morningBriefingProvider.notifier).dismiss(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Open Intents Chip ────────────────────────────────────────────────────

class _OpenIntentsChip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intentsAsync = ref.watch(intentProvider);

    return intentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (intents) {
        final openCount = intents.where((i) => i.isOpen).length;
        if (openCount == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/intents'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: const Border.fromBorderSide(
                    BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_box_outlined,
                      size: 14, color: AppColors.amber),
                  const SizedBox(width: 6),
                  Text(
                    '$openCount open commitment${openCount == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      size: 14, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Error Banner ──────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.error, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.redAccent.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.redAccent),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
          ),
        ],
      ),
    );
  }
}
