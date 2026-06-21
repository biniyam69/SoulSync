import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/morning_briefing.dart';
import '../providers/soul_provider.dart';
import '../providers/morning_briefing_provider.dart';
import '../services/tts_service.dart';
import '../providers/app_providers.dart';
import '../widgets/soul_orb.dart';

class MorningBriefingScreen extends ConsumerStatefulWidget {
  final MorningBriefing briefing;

  const MorningBriefingScreen({super.key, required this.briefing});

  @override
  ConsumerState<MorningBriefingScreen> createState() =>
      _MorningBriefingScreenState();
}

class _MorningBriefingScreenState extends ConsumerState<MorningBriefingScreen> {
  bool _isPlaying = false;
  bool _hasPlayed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    ref.read(ttsServiceProvider).stop();
    super.dispose();
  }

  Future<void> _play() async {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    try {
      await ref.read(ttsServiceProvider).speak(widget.briefing.content);
    } finally {
      if (mounted) setState(() => _isPlaying = false);
    }
    setState(() => _hasPlayed = true);
  }

  Future<void> _stop() async {
    await ref.read(ttsServiceProvider).stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _dismiss() async {
    await _stop();
    await ref.read(morningBriefingProvider.notifier).dismiss();
    if (!mounted) return;
    Navigator.pop(context);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final soul = ref.watch(soulProvider);
    final phase = _isPlaying ? AppPhase.speaking : AppPhase.idle;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: _dismiss,
                ),
              ),
            ),

            // Orb
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SoulOrb(
                phase: phase,
                soundLevel: _isPlaying ? soul.soundLevel + 0.5 : 0,
                size: 130,
              ),
            ),

            // Greeting
            Text(
              _greeting(),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Daily Briefing',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 24),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.border, width: 0.5),
                  ),
                  child: Text(
                    widget.briefing.content,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                children: [
                  // Play / Stop
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPlaying ? _stop : _play,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.orbSpeaking,
                        side: const BorderSide(
                            color: AppColors.orbSpeaking, width: 0.8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(
                        _isPlaying
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _isPlaying ? 'Stop' : 'Play',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Dismiss
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _dismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        "Let's go",
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
