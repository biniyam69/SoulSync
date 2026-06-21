import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/intent.dart';
import '../services/storage_service.dart';
import '../services/claude_service.dart';
import 'app_providers.dart';

class IntentNotifier extends AsyncNotifier<List<Intent>> {
  static const _uuid = Uuid();
  late StorageService _storage;
  late ClaudeService _claude;

  @override
  Future<List<Intent>> build() async {
    _storage = ref.watch(storageServiceProvider);
    _claude = ref.watch(claudeServiceProvider);
    return _storage.loadIntents();
  }

  Future<void> processUtterance(String text, String entryId) async {
    final extracted = await _claude.extractIntent(text, entryId);
    if (extracted == null) return;

    final intent = Intent(
      id: _uuid.v4(),
      text: extracted,
      rawText: text,
      sourceEntryId: entryId,
      createdAt: DateTime.now(),
    );

    final current = state.valueOrNull ?? [];
    final updated = [...current, intent];
    await _storage.saveIntents(updated);
    state = AsyncData(updated);
  }

  Future<void> markDone(String id) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    current[idx].status = IntentStatus.done;
    current[idx].completedAt = DateTime.now();
    await _storage.saveIntents(current);
    state = AsyncData(List.from(current));
  }

  Future<void> dismiss(String id) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    current[idx].status = IntentStatus.dismissed;
    await _storage.saveIntents(current);
    state = AsyncData(List.from(current));
  }

  Future<void> deleteIntent(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((i) => i.id != id).toList();
    await _storage.saveIntents(updated);
    state = AsyncData(updated);
  }

  List<Intent> get openIntents =>
      (state.valueOrNull ?? []).where((i) => i.isOpen).toList();

  List<Intent> get recentOpen {
    final open = openIntents;
    open.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return open.take(5).toList();
  }

  // Returns intents that are overdue for a follow-up (> 2 days old and still open)
  List<Intent> get overdueIntents => openIntents
      .where((i) => i.ageDays >= 2)
      .toList()
    ..sort((a, b) => b.ageDays.compareTo(a.ageDays));
}

final intentProvider =
    AsyncNotifierProvider<IntentNotifier, List<Intent>>(IntentNotifier.new);
