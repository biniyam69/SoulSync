import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/daily_session.dart';
import '../models/memory_entry.dart';
import '../models/speaker.dart';
import '../models/intent.dart';
import '../models/person.dart';
import '../models/introspection_entry.dart';
import '../models/morning_briefing.dart';

class StorageService {
  late Directory _baseDir;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final appDir = await getApplicationDocumentsDirectory();
    _baseDir = appDir;
    await Directory('${_baseDir.path}/transcripts').create(recursive: true);
    await Directory('${_baseDir.path}/memory').create(recursive: true);
    await Directory('${_baseDir.path}/introspection').create(recursive: true);
    _initialized = true;
  }

  // ─── Transcripts ────────────────────────────────────────────────────────

  String _transcriptPath(String date) =>
      '${_baseDir.path}/transcripts/$date.json';

  Future<DailySession> loadSession(String date) async {
    final file = File(_transcriptPath(date));
    if (!await file.exists()) return DailySession(date: date);
    try {
      final json = jsonDecode(await file.readAsString());
      return DailySession.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return DailySession(date: date);
    }
  }

  Future<void> saveSession(DailySession session) async {
    await init();
    final file = File(_transcriptPath(session.date));
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<List<String>> listSessionDates() async {
    await init();
    final dir = Directory('${_baseDir.path}/transcripts');
    if (!await dir.exists()) return [];
    final files = await dir.list().toList();
    return files
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  // ─── Memory ─────────────────────────────────────────────────────────────

  String _memoryPath(String date) => '${_baseDir.path}/memory/$date.json';

  Future<MemoryEntry?> loadMemory(String date) async {
    final file = File(_memoryPath(date));
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      return MemoryEntry.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMemory(MemoryEntry entry) async {
    await init();
    final file = File(_memoryPath(entry.date));
    await file.writeAsString(jsonEncode(entry.toJson()));
  }

  Future<List<MemoryEntry>> loadAllMemories() async {
    await init();
    final dir = Directory('${_baseDir.path}/memory');
    if (!await dir.exists()) return [];
    final files = await dir.list().toList();
    final memories = <MemoryEntry>[];
    for (final f in files.whereType<File>()) {
      try {
        final json = jsonDecode(await f.readAsString());
        memories.add(MemoryEntry.fromJson(json as Map<String, dynamic>));
      } catch (_) {}
    }
    memories.sort((a, b) => b.date.compareTo(a.date));
    return memories;
  }

  // ─── Speaker Profiles ───────────────────────────────────────────────────

  String get _speakersPath => '${_baseDir.path}/speaker_profiles.json';

  Future<List<Speaker>> loadSpeakers() async {
    await init();
    final file = File(_speakersPath);
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list
          .map((e) => Speaker.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSpeakers(List<Speaker> speakers) async {
    await init();
    await File(_speakersPath).writeAsString(
      jsonEncode(speakers.map((s) => s.toJson()).toList()),
    );
  }

  // ─── Intents ────────────────────────────────────────────────────────────

  String get _intentsPath => '${_baseDir.path}/intents.json';

  Future<List<Intent>> loadIntents() async {
    await init();
    final file = File(_intentsPath);
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list.map((e) => Intent.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveIntents(List<Intent> intents) async {
    await init();
    await File(_intentsPath).writeAsString(
      jsonEncode(intents.map((i) => i.toJson()).toList()),
    );
  }

  // ─── People ─────────────────────────────────────────────────────────────

  String get _peoplePath => '${_baseDir.path}/people.json';

  Future<List<Person>> loadPeople() async {
    await init();
    final file = File(_peoplePath);
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list.map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePeople(List<Person> people) async {
    await init();
    await File(_peoplePath).writeAsString(
      jsonEncode(people.map((p) => p.toJson()).toList()),
    );
  }

  // ─── Introspection ───────────────────────────────────────────────────────

  String get _introspectionPath => '${_baseDir.path}/introspection/entries.json';

  Future<List<IntrospectionEntry>> loadIntrospectionEntries() async {
    await init();
    final file = File(_introspectionPath);
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list
          .map((e) => IntrospectionEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveIntrospectionEntry(IntrospectionEntry entry) async {
    await init();
    final entries = await loadIntrospectionEntries();
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      entries[idx] = entry;
    } else {
      entries.insert(0, entry);
    }
    await File(_introspectionPath).writeAsString(
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  // ─── Morning Briefing ───────────────────────────────────────────────────

  String get _morningBriefingPath => '${_baseDir.path}/morning_briefing.json';

  Future<MorningBriefing?> loadMorningBriefing() async {
    await init();
    final file = File(_morningBriefingPath);
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      return MorningBriefing.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMorningBriefing(MorningBriefing briefing) async {
    await init();
    await File(_morningBriefingPath)
        .writeAsString(jsonEncode(briefing.toJson()));
  }

  // ─── Clear all data ─────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await init();
    final transcriptDir = Directory('${_baseDir.path}/transcripts');
    final memoryDir = Directory('${_baseDir.path}/memory');
    final speakersFile = File(_speakersPath);
    final briefingFile = File(_morningBriefingPath);

    if (await transcriptDir.exists()) await transcriptDir.delete(recursive: true);
    if (await memoryDir.exists()) await memoryDir.delete(recursive: true);
    if (await speakersFile.exists()) await speakersFile.delete();
    if (await briefingFile.exists()) await briefingFile.delete();

    await Directory('${_baseDir.path}/transcripts').create(recursive: true);
    await Directory('${_baseDir.path}/memory').create(recursive: true);
  }
}
