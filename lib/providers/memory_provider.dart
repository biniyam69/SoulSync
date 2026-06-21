import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/memory_entry.dart';
import '../services/storage_service.dart';
import '../services/claude_service.dart';
import 'app_providers.dart';

class MemoryNotifier extends AsyncNotifier<List<MemoryEntry>> {
  late StorageService _storage;
  late ClaudeService _claude;

  @override
  Future<List<MemoryEntry>> build() async {
    _storage = ref.watch(storageServiceProvider);
    _claude = ref.watch(claudeServiceProvider);
    return _storage.loadAllMemories();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _storage.loadAllMemories());
  }

  Future<void> updateEntry(MemoryEntry updated) async {
    updated.updatedAt = DateTime.now();
    await _storage.saveMemory(updated);
    await refresh();
  }

  Future<String> searchMemories(String query) async {
    final memories = state.valueOrNull ?? [];
    if (memories.isEmpty) return 'No memories found yet.';
    return _claude.searchMemories(query: query, memories: memories);
  }
}

final memoryProvider = AsyncNotifierProvider<MemoryNotifier, List<MemoryEntry>>(
  MemoryNotifier.new,
);
