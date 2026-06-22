import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/introspection_entry.dart';
import '../models/emotion.dart';
import '../models/transcript_entry.dart';
import '../models/memory_entry.dart';
import '../models/persona.dart';
import '../services/storage_service.dart';
import '../services/claude_service.dart';
import 'app_providers.dart';
import 'persona_provider.dart';

class IntrospectionState {
  final List<IntrospectionEntry> entries;
  final IntrospectionEntry? pendingQuestion; // awaiting user answer
  final bool isLoading;

  const IntrospectionState({
    this.entries = const [],
    this.pendingQuestion,
    this.isLoading = false,
  });

  IntrospectionState copyWith({
    List<IntrospectionEntry>? entries,
    IntrospectionEntry? pendingQuestion,
    bool? isLoading,
    bool clearPending = false,
  }) => IntrospectionState(
    entries: entries ?? this.entries,
    pendingQuestion: clearPending ? null : (pendingQuestion ?? this.pendingQuestion),
    isLoading: isLoading ?? this.isLoading,
  );
}

class IntrospectionNotifier extends AsyncNotifier<IntrospectionState> {
  static const _uuid = Uuid();
  late StorageService _storage;
  late ClaudeService _claude;

  @override
  Future<IntrospectionState> build() async {
    _storage = ref.watch(storageServiceProvider);
    _claude = ref.watch(claudeServiceProvider);
    final entries = await _storage.loadIntrospectionEntries();
    return IntrospectionState(entries: entries);
  }

  Future<IntrospectionEntry?> generateQuestion({
    required List<TranscriptEntry> recentEntries,
    required List<MemoryEntry> recentMemories,
    required EmotionalState currentMood,
  }) async {
    final persona = ref.read(personaProvider);
    final userName = ref.read(userNameProvider);

    state = AsyncData(state.requireValue.copyWith(isLoading: true));

    try {
      final question = await _claude.generateIntrospectionQuestion(
        userName: userName,
        recentEntries: recentEntries,
        recentMemories: recentMemories,
        persona: persona,
        currentMood: currentMood,
      );

      final entry = IntrospectionEntry(
        id: _uuid.v4(),
        date: DateTime.now(),
        question: question,
        mood: currentMood,
      );

      state = AsyncData(state.requireValue.copyWith(
        pendingQuestion: entry,
        isLoading: false,
      ));

      return entry;
    } catch (_) {
      state = AsyncData(state.requireValue.copyWith(isLoading: false));
      return null;
    }
  }

  Future<void> recordAnswer(String entryId, String answer) async {
    final current = state.valueOrNull ?? const IntrospectionState();
    final pending = current.pendingQuestion;
    if (pending == null || pending.id != entryId) return;

    final updated = IntrospectionEntry(
      id: pending.id,
      date: pending.date,
      question: pending.question,
      answer: answer,
      mood: pending.mood,
    );

    await _storage.saveIntrospectionEntry(updated);
    final allEntries = await _storage.loadIntrospectionEntries();

    state = AsyncData(current.copyWith(
      entries: allEntries,
      clearPending: true,
    ));
  }

  void dismissPending() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearPending: true));
  }
}

final introspectionProvider =
    AsyncNotifierProvider<IntrospectionNotifier, IntrospectionState>(
  IntrospectionNotifier.new,
);
