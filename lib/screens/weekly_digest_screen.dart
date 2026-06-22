import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../providers/app_providers.dart';
import '../providers/intent_provider.dart';
import '../providers/persona_provider.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../widgets/soul_orb.dart';
import '../providers/soul_provider.dart';

class WeeklyDigestScreen extends ConsumerStatefulWidget {
  const WeeklyDigestScreen({super.key});

  @override
  ConsumerState<WeeklyDigestScreen> createState() => _WeeklyDigestScreenState();
}

class _WeeklyDigestScreenState extends ConsumerState<WeeklyDigestScreen> {
  String? _digest;
  bool _loading = true;
  bool _isPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    ref.read(ttsServiceProvider).stop();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final storage = ref.read(storageServiceProvider);
      final claude = ref.read(claudeServiceProvider);
      final userName = ref.read(userNameProvider);
      final persona = ref.read(personaProvider);

      await storage.init();
      final allMemories = await storage.loadAllMemories();
      final weekMemories = allMemories.take(7).toList();
      final intents = await storage.loadIntents();
      final done = intents.where((i) => i.isDone).toList();
      final open = intents.where((i) => i.isOpen).toList();

      final digest = await claude.generateWeeklyDigest(
        userName: userName,
        weekMemories: weekMemories,
        completedIntents: done,
        openIntents: open,
        persona: persona,
      );

      if (mounted) {
        setState(() {
          _digest = digest;
          _loading = false;
        });
        // Auto-play
        _play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not generate digest. Check your API key and try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _play() async {
    if (_digest == null || _isPlaying) return;
    setState(() => _isPlaying = true);
    try {
      await ref.read(ttsServiceProvider).speak(_digest!);
    } finally {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _stop() async {
    await ref.read(ttsServiceProvider).stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    final soul = ref.watch(soulProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Weekly Digest',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (!_loading && _digest != null)
            TextButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh_rounded,
                  size: 16, color: AppColors.textTertiary),
              label: Text(
                'Regenerate',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SoulOrb(
                    phase: AppPhase.speaking,
                    soundLevel: 0.4,
                    size: 100,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Reflecting on your week...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.textTertiary, size: 40),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _generate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amber,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Try again',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Orb when playing
                    if (_isPlaying)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SoulOrb(
                          phase: AppPhase.speaking,
                          soundLevel: soul.soundLevel + 0.3,
                          size: 80,
                        ),
                      ),

                    // Digest text
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: const Border.fromBorderSide(
                                BorderSide(color: AppColors.border, width: 0.5)),
                          ),
                          child: Text(
                            _digest ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              height: 1.75,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Controls
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isPlaying ? _stop : _play,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.orbSpeaking,
                                side: const BorderSide(
                                    color: AppColors.orbSpeaking, width: 0.8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: Icon(
                                _isPlaying
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                                size: 20,
                              ),
                              label: Text(
                                _isPlaying ? 'Stop' : 'Play',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.amber,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                'Done',
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
