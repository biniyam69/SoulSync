import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/transcript_entry.dart';
import '../models/daily_session.dart';
import '../models/memory_entry.dart';
import '../models/speaker.dart';
import '../services/claude_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/speaker_service.dart';
import '../services/storage_service.dart';
import 'app_providers.dart';

// ─── State ──────────────────────────────────────────────────────────────────

enum AppPhase { idle, listening, checkin, speaking, nightlyReview }

class SoulState {
  final AppPhase phase;
  final bool isListening;
  final bool isSpeaking;
  final double soundLevel;
  final String partialText;
  final DailySession session;
  final DateTime? nextCheckinAt;
  final String? assistantMessage;
  final bool initialized;
  final String? error;

  const SoulState({
    this.phase = AppPhase.idle,
    this.isListening = false,
    this.isSpeaking = false,
    this.soundLevel = 0,
    this.partialText = '',
    required this.session,
    this.nextCheckinAt,
    this.assistantMessage,
    this.initialized = false,
    this.error,
  });

  SoulState copyWith({
    AppPhase? phase,
    bool? isListening,
    bool? isSpeaking,
    double? soundLevel,
    String? partialText,
    DailySession? session,
    DateTime? nextCheckinAt,
    String? assistantMessage,
    bool? initialized,
    String? error,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return SoulState(
      phase: phase ?? this.phase,
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      soundLevel: soundLevel ?? this.soundLevel,
      partialText: partialText ?? this.partialText,
      session: session ?? this.session,
      nextCheckinAt: nextCheckinAt ?? this.nextCheckinAt,
      assistantMessage:
          clearMessage ? null : (assistantMessage ?? this.assistantMessage),
      initialized: initialized ?? this.initialized,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class SoulNotifier extends Notifier<SoulState> {
  static const _uuid = Uuid();
  Timer? _checkinTimer;
  StreamSubscription<bool>? _ttsSub;

  late SpeechService _speech;
  late TtsService _tts;
  late SpeakerService _speakers;
  late StorageService _storage;
  late ClaudeService _claude;
  late SharedPreferences _prefs;

  @override
  SoulState build() {
    _speech = ref.watch(speechServiceProvider);
    _tts = ref.watch(ttsServiceProvider);
    _speakers = ref.watch(speakerServiceProvider);
    _storage = ref.watch(storageServiceProvider);
    _claude = ref.watch(claudeServiceProvider);
    _prefs = ref.watch(sharedPreferencesProvider);

    // Listen to TTS speaking state
    _ttsSub?.cancel();
    _ttsSub = _tts.speakingStream.listen((speaking) {
      state = state.copyWith(isSpeaking: speaking);
    });

    ref.onDispose(() {
      _checkinTimer?.cancel();
      _ttsSub?.cancel();
    });

    final today = _todayDate();
    return SoulState(session: DailySession(date: today));
  }

  // ─── Init ────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (state.initialized) return;
    await _storage.init();
    await _speakers.load();

    final today = _todayDate();
    final session = await _storage.loadSession(today);

    final initialized = await _speech.initialize();

    state = state.copyWith(
      session: session,
      initialized: true,
      error: initialized ? null : 'Microphone permission denied',
    );
  }

  // ─── Listening ───────────────────────────────────────────────────────────

  Future<void> startListening() async {
    if (!state.initialized || state.isListening) return;

    _speech.onPartialResult = (text) {
      state = state.copyWith(partialText: text);
    };

    _speech.onUtteranceComplete = (text, soundLevel) async {
      await _onUtterance(text, soundLevel);
    };

    _speech.onSoundLevel = (level) {
      state = state.copyWith(soundLevel: level);
    };

    await _speech.startListening();
    state = state.copyWith(phase: AppPhase.listening, isListening: true);

    _armCheckinTimer();
    _scheduleSpeechRestart();
  }

  Future<void> stopListening() async {
    _checkinTimer?.cancel();
    await _speech.stopListening();
    await _tts.stop();
    state = state.copyWith(
      phase: AppPhase.idle,
      isListening: false,
      isSpeaking: false,
      partialText: '',
    );
  }

  void _scheduleSpeechRestart() {
    if (!state.isListening) return;
    // speech_to_text auto-stops after pause; watch and restart
    Future.delayed(const Duration(seconds: 65), () async {
      if (state.isListening && !state.isSpeaking) {
        await _speech.stopListening();
        await Future.delayed(const Duration(milliseconds: 300));
        await _speech.startListening();
        _scheduleSpeechRestart();
      }
    });
  }

  // ─── Utterance handling ──────────────────────────────────────────────────

  Future<void> _onUtterance(String text, double soundLevel) async {
    final speakerId = _speakers.identifySpeaker(soundLevel);
    final speakerLabel = _speakers.speakerLabel(speakerId);

    final entry = TranscriptEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      text: text,
      speakerId: speakerId,
      speakerLabel: speakerLabel,
    );

    final updatedEntries = [...state.session.entries, entry];
    final updatedSession = state.session.copyWith(entries: updatedEntries);
    state = state.copyWith(
      session: updatedSession,
      partialText: '',
    );
    await _storage.saveSession(updatedSession);

    // If user is speaking, respond conversationally
    if (speakerId == SpeakerIds.user) {
      await _respondToUser(text, updatedEntries);
    }
  }

  Future<void> _respondToUser(
    String userText,
    List<TranscriptEntry> history,
  ) async {
    if (state.isSpeaking) return;

    final userName = _prefs.getString(AppConstants.prefUserName) ?? '';

    state = state.copyWith(phase: AppPhase.speaking);

    try {
      await _speech.stopListening();

      final reply = await _claude.reply(
        userName: userName,
        conversationHistory: history,
        memories: <MemoryEntry>[],
        latestUserMessage: userText,
      );

      await _addAssistantEntry(reply);
      await _tts.speak(reply);

      if (state.isListening) {
        await _speech.restartAfterTts();
        state = state.copyWith(phase: AppPhase.listening);
      }
    } catch (e) {
      state = state.copyWith(phase: AppPhase.listening, error: e.toString());
    }
  }

  Future<void> _addAssistantEntry(String text) async {
    final entry = TranscriptEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      text: text,
      speakerId: SpeakerIds.assistant,
      speakerLabel: 'SoulSync',
      isAssistant: true,
    );
    final updatedEntries = [...state.session.entries, entry];
    final updatedSession = state.session.copyWith(entries: updatedEntries);
    state = state.copyWith(session: updatedSession, assistantMessage: text);
    await _storage.saveSession(updatedSession);
  }

  // ─── Proactive check-ins ─────────────────────────────────────────────────

  void _armCheckinTimer() {
    _checkinTimer?.cancel();
    if (!(_prefs.getBool(AppConstants.prefCheckInEnabled) ?? true)) return;

    final minMin = _prefs.getInt(AppConstants.prefCheckInMinInterval) ??
        AppConstants.minCheckInMinutes;
    final maxMin = _prefs.getInt(AppConstants.prefCheckInMaxInterval) ??
        AppConstants.maxCheckInMinutes;
    final intervalMin = minMin + Random().nextInt(maxMin - minMin + 1);

    final next = DateTime.now().add(Duration(minutes: intervalMin));
    state = state.copyWith(nextCheckinAt: next);

    _checkinTimer = Timer(Duration(minutes: intervalMin), _triggerCheckin);
  }

  Future<void> _triggerCheckin() async {
    if (!state.isListening || state.isSpeaking) {
      _armCheckinTimer();
      return;
    }

    final hour = DateTime.now().hour;
    final nightModeEnabled =
        _prefs.getBool(AppConstants.prefNightModeEnabled) ?? true;
    if (nightModeEnabled &&
        (hour >= AppConstants.nightModeStart || hour < AppConstants.nightModeEnd)) {
      _armCheckinTimer();
      return;
    }

    state = state.copyWith(phase: AppPhase.checkin);
    try {
      await _speech.stopListening();
      final userName = _prefs.getString(AppConstants.prefUserName) ?? '';
      final recent = state.session.entries.reversed.take(8).toList().reversed.toList();

      final phrase = await _claude.generateCheckin(
        userName: userName,
        recentEntries: recent,
        now: DateTime.now(),
      );

      await _addAssistantEntry(phrase);
      await _tts.speak(phrase);

      if (state.isListening) {
        await _speech.restartAfterTts();
        state = state.copyWith(phase: AppPhase.listening);
      }
    } catch (_) {
      state = state.copyWith(phase: AppPhase.listening);
    }

    _armCheckinTimer();
  }

  // ─── Manual speak ────────────────────────────────────────────────────────

  Future<void> askAssistant(String text) async {
    await _onUtterance(text, _speakers.userProfile?.voiceSignature.isNotEmpty == true
        ? _speakers.userProfile!.voiceSignature[0]
        : 0.0);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _todayDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  void clearError() => state = state.copyWith(clearError: true);
}

// ─── Provider ───────────────────────────────────────────────────────────────

final soulProvider = NotifierProvider<SoulNotifier, SoulState>(
  SoulNotifier.new,
);
