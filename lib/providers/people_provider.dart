import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/person.dart';
import '../models/daily_session.dart';
import '../services/storage_service.dart';
import '../services/claude_service.dart';
import 'app_providers.dart';

class PeopleNotifier extends AsyncNotifier<List<Person>> {
  static const _uuid = Uuid();
  late StorageService _storage;
  late ClaudeService _claude;

  @override
  Future<List<Person>> build() async {
    _storage = ref.watch(storageServiceProvider);
    _claude = ref.watch(claudeServiceProvider);
    return _storage.loadPeople();
  }

  Future<void> extractFromSession(DailySession session) async {
    final userName = ref.read(userNameProvider);
    final extracted = await _claude.extractPeopleFromSession(
      session: session,
      userName: userName,
    );

    if (extracted.isEmpty) return;

    final current = state.valueOrNull ?? [];

    for (final data in extracted) {
      final name = data['name'] ?? '';
      if (name.isEmpty) continue;

      final existing = current.indexWhere(
        (p) => p.name.toLowerCase() == name.toLowerCase(),
      );

      if (existing != -1) {
        // Update existing person
        final p = current[existing];
        p.mentionCount++;
        p.lastMentionedAt = DateTime.now();
        final context = data['context'] ?? '';
        if (context.isNotEmpty && p.contextSnippets.length < 10) {
          p.contextSnippets.add(context);
        }
      } else {
        // Add new person
        final rel = Relationship.values.firstWhere(
          (r) => r.name == (data['relationship'] ?? 'unknown'),
          orElse: () => Relationship.unknown,
        );
        current.add(Person(
          id: _uuid.v4(),
          name: name,
          relationship: rel,
          firstMentionedAt: DateTime.now(),
          lastMentionedAt: DateTime.now(),
          contextSnippets: data['context'] != null ? [data['context']!] : [],
        ));
      }
    }

    await _storage.savePeople(current);
    state = AsyncData(List.from(current));
  }

  Future<void> updatePerson(Person person) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((p) => p.id == person.id);
    if (idx != -1) current[idx] = person;
    await _storage.savePeople(current);
    state = AsyncData(List.from(current));
  }

  Future<void> deletePerson(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((p) => p.id != id).toList();
    await _storage.savePeople(updated);
    state = AsyncData(updated);
  }

  List<Person> get byFrequency {
    final all = state.valueOrNull ?? [];
    return [...all]..sort((a, b) => b.mentionCount.compareTo(a.mentionCount));
  }
}

final peopleProvider =
    AsyncNotifierProvider<PeopleNotifier, List<Person>>(PeopleNotifier.new);
