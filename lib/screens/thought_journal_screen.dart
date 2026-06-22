import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/transcript_entry.dart';
import '../models/speaker.dart';
import '../providers/soul_provider.dart';
import '../providers/app_providers.dart';
import '../services/claude_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../widgets/soul_orb.dart';
import '../widgets/waveform_widget.dart';

class ThoughtJournalScreen extends ConsumerStatefulWidget {
  const ThoughtJournalScreen({super.key});

  @override
  ConsumerState<ThoughtJournalScreen> createState() =>
      _ThoughtJournalScreenState();
}

class _ThoughtJournalScreenState extends ConsumerState<ThoughtJournalScreen> {
  SpeechService? _speech;
  bool _isRecording = false;
  double _soundLevel = 0;
  final List<TranscriptEntry> _entries = [];
  String _partialText = '';
  String? _summary;
  bool _generatingSummary = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _speech?.stopListening();
    _speech?.dispose();
    super.dispose();
  }

  Future<void> _startJournaling() async {
    _speech = SpeechService();
    final ok = await _speech!.initialize();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Microphone not available')),
      );
      return;
    }

    _speech!.onSoundLevel = (level) {
      if (mounted) setState(() => _soundLevel = level);
    };

    _speech!.onPartialResult = (text) {
      if (mounted) setState(() => _partialText = text);
    };

    _speech!.onUtteranceComplete = (text, level) {
      if (!mounted) return;
      final entry = TranscriptEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        text: text,
        speakerId: SpeakerIds.user,
        speakerLabel: 'You',
        type: EntryType.thought,
      );
      setState(() {
        _entries.add(entry);
        _partialText = '';
      });
      // Auto-restart after pause
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_isRecording && mounted) _speech?.startListening();
      });
    };

    await _speech!.startListening();
    setState(() {
      _isRecording = true;
      _startTime = DateTime.now();
    });
  }

  Future<void> _stopAndReflect() async {
    await _speech?.stopListening();
    _speech?.dispose();
    _speech = null;
    setState(() {
      _isRecording = false;
      _generatingSummary = true;
    });

    if (_entries.isEmpty) {
      setState(() => _generatingSummary = false);
      return;
    }

    try {
      final claude = ref.read(claudeServiceProvider);
      final summary = await claude.summarizeThoughtJournal(_entries);
      setState(() {
        _summary = summary;
        _generatingSummary = false;
      });

      // Speak the reflection
      final tts = ref.read(ttsServiceProvider);
      await tts.speak(summary);
    } catch (e) {
      setState(() => _generatingSummary = false);
    }
  }

  String get _durationText {
    if (_startTime == null) return '';
    final diff = DateTime.now().difference(_startTime!);
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Thought Journal',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          onPressed: () {
            _speech?.stopListening();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Status + orb
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                SoulOrb(
                  phase: _isRecording ? AppPhase.listening : AppPhase.idle,
                  soundLevel: _soundLevel,
                  size: 120,
                ),
                const SizedBox(height: 16),
                Text(
                  _isRecording
                      ? 'Speaking freely... $_durationText'
                      : _summary != null
                          ? 'Reflection complete'
                          : 'Your thoughts, uninterrupted',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_isRecording) ...[
                  const SizedBox(height: 12),
                  WaveformWidget(
                    soundLevel: _soundLevel,
                    barCount: 9,
                    height: 36,
                  ),
                ],
              ],
            ),
          ),

          // Partial text
          if (_partialText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                _partialText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Summary
          if (_summary != null)
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.orbSpeaking.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.orbSpeaking.withOpacity(0.2), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REFLECTION',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.orbSpeaking.withOpacity(0.8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _summary!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

          // Transcript entries
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Text(
                      _isRecording
                          ? 'Listening...'
                          : 'Press Start to begin journaling',
                      style: GoogleFonts.inter(
                          color: AppColors.textTertiary, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _entries.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _entries[i].text,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: _generatingSummary
                ? Column(
                    children: [
                      const CircularProgressIndicator(color: AppColors.amber),
                      const SizedBox(height: 12),
                      Text(
                        'Reflecting...',
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  )
                : _summary != null
                    ? SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Done',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          if (_isRecording)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _stopAndReflect,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.surfaceElevated,
                                  foregroundColor: AppColors.textPrimary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: const Icon(Icons.stop_rounded, size: 18),
                                label: Text(
                                  'Stop & Reflect',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _startJournaling,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.amber,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: const Icon(Icons.mic_rounded, size: 18),
                                label: Text(
                                  'Start Journaling',
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
