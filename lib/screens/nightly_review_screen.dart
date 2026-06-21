import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../providers/review_provider.dart';
import '../providers/soul_provider.dart';
import '../widgets/soul_orb.dart';

class NightlyReviewScreen extends ConsumerStatefulWidget {
  const NightlyReviewScreen({super.key});

  @override
  ConsumerState<NightlyReviewScreen> createState() =>
      _NightlyReviewScreenState();
}

class _NightlyReviewScreenState extends ConsumerState<NightlyReviewScreen> {
  final Map<String, TextEditingController> _nameControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(reviewProvider.notifier);
      notifier.beginReview(notifier.todayDate());
    });
  }

  @override
  void dispose() {
    for (final c in _nameControllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewAsync = ref.watch(reviewProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Nightly Review',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: reviewAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(error: e.toString()),
        data: (state) => _ReviewBody(
          state: state,
          nameControllers: _nameControllers,
          onPlayNarrative: () =>
              ref.read(reviewProvider.notifier).playNarrative(),
          onStopNarrative: () =>
              ref.read(reviewProvider.notifier).stopNarrative(),
          onProceedToCorrection: () =>
              ref.read(reviewProvider.notifier).proceedToSpeakerCorrection(),
          onCorrectSpeaker: (id, name) =>
              ref.read(reviewProvider.notifier).correctSpeaker(id, name),
          onFinalize: () => ref.read(reviewProvider.notifier).finalizeReview(),
          onDone: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  final ReviewState state;
  final Map<String, TextEditingController> nameControllers;
  final VoidCallback onPlayNarrative;
  final VoidCallback onStopNarrative;
  final VoidCallback onProceedToCorrection;
  final void Function(String, String) onCorrectSpeaker;
  final VoidCallback onFinalize;
  final VoidCallback onDone;

  const _ReviewBody({
    required this.state,
    required this.nameControllers,
    required this.onPlayNarrative,
    required this.onStopNarrative,
    required this.onProceedToCorrection,
    required this.onCorrectSpeaker,
    required this.onFinalize,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    switch (state.phase) {
      case ReviewPhase.loading:
        return const _LoadingView();
      case ReviewPhase.narrative:
        return _NarrativeView(
          state: state,
          onPlay: onPlayNarrative,
          onStop: onStopNarrative,
          onProceed: onProceedToCorrection,
        );
      case ReviewPhase.speakerCorrection:
        return _SpeakerCorrectionView(
          state: state,
          nameControllers: nameControllers,
          onCorrect: onCorrectSpeaker,
          onFinalize: onFinalize,
        );
      case ReviewPhase.generating:
        return const _GeneratingView();
      case ReviewPhase.complete:
        return _CompleteView(state: state, onDone: onDone);
    }
  }
}

// ─── Loading ───────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.amber),
    );
  }
}

// ─── Error ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          error,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.redAccent),
        ),
      ),
    );
  }
}

// ─── Narrative Phase ───────────────────────────────────────────────────────

class _NarrativeView extends StatelessWidget {
  final ReviewState state;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback onProceed;

  const _NarrativeView({
    required this.state,
    required this.onPlay,
    required this.onStop,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SoulOrb(
                phase: AppPhase.nightlyReview,
                size: 100,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Here's your day",
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  state.narrative ?? 'Generating your daily narrative...',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.7,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.isPlaying ? onStop : onPlay,
                    icon: Icon(
                      state.isPlaying
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.amber,
                    ),
                    label: Text(
                      state.isPlaying ? 'Stop' : 'Listen',
                      style: GoogleFonts.inter(color: AppColors.amber),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.amber),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onProceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Speaker Correction Phase ──────────────────────────────────────────────

class _SpeakerCorrectionView extends StatelessWidget {
  final ReviewState state;
  final Map<String, TextEditingController> nameControllers;
  final void Function(String, String) onCorrect;
  final VoidCallback onFinalize;

  const _SpeakerCorrectionView({
    required this.state,
    required this.nameControllers,
    required this.onCorrect,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
    final unknownSpeakers = state.unknownSpeakerIds;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Who did you talk to?',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Assign names to the voices recorded today.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (unknownSpeakers.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Only your voice was detected today.',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: unknownSpeakers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final speakerId = unknownSpeakers[i];
                    final samples = state.samplesFor(speakerId);

                    nameControllers.putIfAbsent(
                      speakerId,
                      () => TextEditingController(
                          text: state.speakerCorrections[speakerId] ?? ''),
                    );

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: const Border.fromBorderSide(
                            BorderSide(color: AppColors.border, width: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            speakerId,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.other,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Sample quotes
                          ...samples.take(2).map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '"${e.text}"',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameControllers[speakerId],
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter name (or leave blank to skip)',
                              hintStyle: GoogleFonts.inter(
                                  color: AppColors.textTertiary, fontSize: 13),
                              filled: true,
                              fillColor: AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppColors.amber, width: 1),
                              ),
                            ),
                            onChanged: (v) {
                              if (v.trim().isNotEmpty) {
                                onCorrect(speakerId, v.trim());
                              }
                            },
                            textCapitalization: TextCapitalization.words,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onFinalize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  'Save & Generate Memory',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Generating Phase ──────────────────────────────────────────────────────

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SoulOrb(phase: AppPhase.nightlyReview, size: 120),
          const SizedBox(height: 32),
          Text(
            'Reflecting on your day...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Complete Phase ────────────────────────────────────────────────────────

class _CompleteView extends StatelessWidget {
  final ReviewState state;
  final VoidCallback onDone;

  const _CompleteView({required this.state, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final memory = state.generatedMemory;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SoulOrb(phase: AppPhase.idle, size: 100),
            ),
            const SizedBox(height: 32),
            Text(
              'Day documented',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 12),
            if (memory != null) ...[
              Text(
                memory.summary,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              if (memory.keyPeople.isNotEmpty) ...[
                _MemoryChips(label: 'People', items: memory.keyPeople),
                const SizedBox(height: 10),
              ],
              if (memory.userMoods.isNotEmpty)
                _MemoryChips(label: 'Mood', items: memory.userMoods),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  'Sleep well',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryChips extends StatelessWidget {
  final String label;
  final List<String> items;
  const _MemoryChips({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.amberDim,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.amber),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
