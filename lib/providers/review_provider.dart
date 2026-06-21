import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/daily_session.dart';
import '../models/memory_entry.dart';
import '../models/transcript_entry.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../services/speaker_service.dart';
import 'app_providers.dart';

enum ReviewPhase { loading, narrative, speakerCorrection, generating, complete }

class ReviewState {
  final ReviewPhase phase;
  final DailySession? session;
  final String? narrative;
  final Map<String, String> speakerCorrections; // speakerId -> newName
  final MemoryEntry? generatedMemory;
  final bool isPlaying;
  final String? error;

  const ReviewState({
    this.phase = ReviewPhase.loading,
    this.session,
    this.narrative,
    this.speakerCorrections = const {},
    this.generatedMemory,
    this.isPlaying = false,
    this.error,
  });

  ReviewState copyWith({
    ReviewPhase? phase,
    DailySession? session,
    String? narrative,
    Map<String, String>? speakerCorrections,
    MemoryEntry? generatedMemory,
    bool? isPlaying,
    String? error,
    bool clearError = false,
  }) {
    return ReviewState(
      phase: phase ?? this.phase,
      session: session ?? this.session,
      narrative: narrative ?? this.narrative,
      speakerCorrections: speakerCorrections ?? this.speakerCorrections,
      generatedMemory: generatedMemory ?? this.generatedMemory,
      isPlaying: isPlaying ?? this.isPlaying,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<String> get unknownSpeakerIds {
    if (session == null) return [];
    return session!.entries
        .where((e) => !e.isAssistant && e.speakerId != 'user')
        .map((e) => e.speakerId)
        .toSet()
        .toList();
  }

  List<TranscriptEntry> samplesFor(String speakerId) {
    if (session == null) return [];
    return session!.entries
        .where((e) => e.speakerId == speakerId)
        .take(3)
        .toList();
  }
}

class ReviewNotifier extends AsyncNotifier<ReviewState> {
  late ClaudeService _claude;
  late StorageService _storage;
  late TtsService _tts;
  late SpeakerService _speakers;

  @override
  Future<ReviewState> build() async {
    _claude = ref.watch(claudeServiceProvider);
    _storage = ref.watch(storageServiceProvider);
    _tts = ref.watch(ttsServiceProvider);
    _speakers = ref.watch(speakerServiceProvider);
    return const ReviewState();
  }

  Future<void> beginReview(String date) async {
    state = const AsyncLoading();

    final session = await _storage.loadSession(date);

    if (session.entries.isEmpty) {
      state = AsyncData(ReviewState(
        phase: ReviewPhase.narrative,
        session: session,
        narrative: 'No conversations were recorded today.',
      ));
      return;
    }

    final userName = ref.read(userNameProvider);

    try {
      final narrative = await _claude.generateNightlyNarrative(
        userName: userName,
        session: session,
      );

      state = AsyncData(ReviewState(
        phase: ReviewPhase.narrative,
        session: session,
        narrative: narrative,
      ));
    } catch (e) {
      state = AsyncData(ReviewState(
        phase: ReviewPhase.speakerCorrection,
        session: session,
        error: e.toString(),
      ));
    }
  }

  Future<void> playNarrative() async {
    final current = state.valueOrNull;
    if (current?.narrative == null) return;

    state = AsyncData(current!.copyWith(isPlaying: true));
    try {
      final sentences = current.narrative!
          .split(RegExp(r'(?<=[.!?])\s+'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
      await _tts.speakSequence(sentences);
    } finally {
      state = AsyncData(state.requireValue.copyWith(isPlaying: false));
    }
  }

  void stopNarrative() => _tts.stop();

  void proceedToSpeakerCorrection() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(phase: ReviewPhase.speakerCorrection));
  }

  void correctSpeaker(String speakerId, String name) {
    final current = state.valueOrNull;
    if (current == null) return;
    final corrections = Map<String, String>.from(current.speakerCorrections);
    corrections[speakerId] = name;
    state = AsyncData(current.copyWith(speakerCorrections: corrections));
  }

  Future<void> finalizeReview() async {
    final current = state.valueOrNull;
    if (current?.session == null) return;

    state = AsyncData(current!.copyWith(phase: ReviewPhase.generating));

    // Apply speaker name corrections
    final corrections = current.speakerCorrections;
    for (final entry in corrections.entries) {
      await _speakers.renameSpeaker(entry.key, entry.value);
    }

    // Build speaker name map
    final speakerMap = <String, String>{
      'user': ref.read(userNameProvider).isNotEmpty
          ? ref.read(userNameProvider)
          : 'You',
    };
    for (final e in corrections.entries) {
      speakerMap[e.key] = e.value;
    }
    for (final s in _speakers.profiles) {
      speakerMap.putIfAbsent(s.id, () => s.name);
    }

    try {
      final date =
          current.session!.date;
      final memory = await _claude.generateMemorySummary(
        date: date,
        session: current.session!,
        speakerNameMap: speakerMap,
      );

      await _storage.saveMemory(memory);

      // Mark review complete
      final updatedSession =
          current.session!.copyWith(reviewComplete: true);
      await _storage.saveSession(updatedSession);

      state = AsyncData(state.requireValue.copyWith(
        phase: ReviewPhase.complete,
        generatedMemory: memory,
      ));

      await _tts.speak('Sleep well. I\'ll be here with you tomorrow.');
    } catch (e) {
      state = AsyncData(state.requireValue.copyWith(
        phase: ReviewPhase.complete,
        error: e.toString(),
      ));
    }
  }

  String todayDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());
}

final reviewProvider =
    AsyncNotifierProvider<ReviewNotifier, ReviewState>(ReviewNotifier.new);
