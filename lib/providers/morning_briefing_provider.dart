import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/morning_briefing.dart';
import '../services/storage_service.dart';
import '../services/claude_service.dart';
import 'app_providers.dart';
import 'persona_provider.dart';

class MorningBriefingNotifier extends AsyncNotifier<MorningBriefing?> {
  static const _uuid = Uuid();
  late StorageService _storage;
  late ClaudeService _claude;

  @override
  Future<MorningBriefing?> build() async {
    _storage = ref.watch(storageServiceProvider);
    _claude = ref.watch(claudeServiceProvider);
    await _storage.init();
    return _storage.loadMorningBriefing();
  }

  bool get shouldShow {
    final briefing = state.valueOrNull;
    if (briefing == null) return false;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return briefing.date == today && !briefing.dismissed;
  }

  Future<void> generate() async {
    state = const AsyncLoading();
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterday = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final memory = await _storage.loadMemory(yesterday);
      final intents = await _storage.loadIntents();
      final openIntents = intents.where((i) => i.isOpen).take(5).toList();

      final userName = ref.read(userNameProvider);
      final persona = ref.read(personaProvider);

      final content = await _claude.generateMorningBriefing(
        userName: userName,
        yesterday: memory,
        openIntents: openIntents,
        persona: persona,
      );

      final briefing = MorningBriefing(
        id: _uuid.v4(),
        date: today,
        content: content,
      );

      await _storage.saveMorningBriefing(briefing);
      state = AsyncData(briefing);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> dismiss() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.copyWith(dismissed: true);
    await _storage.saveMorningBriefing(updated);
    state = AsyncData(updated);
  }
}

final morningBriefingProvider =
    AsyncNotifierProvider<MorningBriefingNotifier, MorningBriefing?>(
  MorningBriefingNotifier.new,
);
