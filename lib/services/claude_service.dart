import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/transcript_entry.dart';
import '../models/daily_session.dart';
import '../models/memory_entry.dart';

class ClaudeService {
  String _apiKey;

  ClaudeService(this._apiKey);

  void updateApiKey(String key) => _apiKey = key;

  Future<String> _send({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    int maxTokens = 256,
  }) async {
    if (_apiKey.isEmpty) throw Exception('API key not set');

    final response = await http
        .post(
          Uri.parse(AppConstants.claudeApiUrl),
          headers: {
            'x-api-key': _apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': AppStrings.claudeModel,
            'max_tokens': maxTokens,
            'system': systemPrompt,
            'messages': messages,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error']?['message'] ?? 'Claude API error ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['content'] as List).first['text'] as String;
  }

  // ─── Proactive check-in ────────────────────────────────────────────────

  Future<String> generateCheckin({
    required String userName,
    required List<TranscriptEntry> recentEntries,
    required DateTime now,
  }) async {
    final hour = now.hour;
    final timeContext = hour < 12
        ? 'morning'
        : hour < 17
            ? 'afternoon'
            : hour < 21
                ? 'evening'
                : 'late night';

    final recentText = recentEntries.isEmpty
        ? 'No recent conversations recorded.'
        : recentEntries
            .take(8)
            .map((e) => '${e.speakerLabel}: ${e.text}')
            .join('\n');

    return _send(
      systemPrompt: '''
You are SoulSync, ${userName.isNotEmpty ? "$userName's" : "the user's"} closest digital companion and life documenter.
You speak through their earphones and are always with them.
It is $timeContext. You haven't spoken in a while.
Generate ONE single short, natural, warm check-in phrase — like a best friend breaking comfortable silence.
Keep it under 15 words. No emojis. Be genuine, not robotic.
Vary style: curiosity, care, humor, observation about the time of day.
Do NOT start with "Hey" every time. Mix it up.
Examples: "You've been quiet, everything good?", "What's next on your list?",
"How's that going for you?", "Feeling good today?"
''',
      messages: [
        {
          'role': 'user',
          'content':
              'Recent context:\n$recentText\n\nGenerate a single check-in phrase now.',
        },
      ],
      maxTokens: 60,
    );
  }

  // ─── Conversation reply ────────────────────────────────────────────────

  Future<String> reply({
    required String userName,
    required List<TranscriptEntry> conversationHistory,
    required List<MemoryEntry> memories,
    required String latestUserMessage,
  }) async {
    final memoryContext = memories.isEmpty
        ? ''
        : memories
            .take(7)
            .map((m) => '${m.date}:\n${m.toReadableText()}')
            .join('\n\n');

    final history = conversationHistory
        .where((e) => e.isAssistant || e.speakerId == 'user')
        .takeLast(10)
        .map((e) => {
              'role': e.isAssistant ? 'assistant' : 'user',
              'content': e.text,
            })
        .toList();

    if (history.isEmpty || history.last['role'] != 'user') {
      history.add({'role': 'user', 'content': latestUserMessage});
    }

    return _send(
      systemPrompt: '''
${AppStrings.systemPrompt}
User name: ${userName.isNotEmpty ? userName : 'unknown'}
Memory from past days:
$memoryContext
''',
      messages: history,
      maxTokens: AppConstants.maxVoiceTokens,
    );
  }

  // ─── Nightly review narrative ──────────────────────────────────────────

  Future<String> generateNightlyNarrative({
    required String userName,
    required DailySession session,
  }) async {
    final transcript = session.entries
        .map((e) =>
            '[${_formatTime(e.timestamp)}] ${e.speakerLabel}: ${e.text}')
        .join('\n');

    return _send(
      systemPrompt: '''
You are SoulSync reviewing ${userName.isNotEmpty ? "$userName's" : "the user's"} day with them.
Read this transcript and narrate the day in 2-3 warm, reflective paragraphs — like a good friend
summarizing the day's journey. Mention key moments, themes, and people.
Keep it personal and observational, not analytical. Speak in second person ("You started your day...", "Later you talked with...").
No bullet points. Natural, flowing prose. Keep it under 200 words.
''',
      messages: [
        {
          'role': 'user',
          'content': "Today's transcript:\n\n$transcript",
        },
      ],
      maxTokens: AppConstants.maxReviewTokens,
    );
  }

  // ─── Memory summary ────────────────────────────────────────────────────

  Future<MemoryEntry> generateMemorySummary({
    required String date,
    required DailySession session,
    required Map<String, String> speakerNameMap,
  }) async {
    final transcript = session.entries
        .map((e) {
          final name = speakerNameMap[e.speakerId] ?? e.speakerLabel;
          return '[${_formatTime(e.timestamp)}] $name: ${e.text}';
        })
        .join('\n');

    final speakerList = speakerNameMap.entries
        .map((e) => '${e.key} = ${e.value}')
        .join(', ');

    final response = await _send(
      systemPrompt: '''
You are generating a structured memory entry for a life-documentation app.
Based on the transcript, generate a JSON memory entry inside <json></json> tags.

Required JSON structure:
{
  "summary": "2-3 sentence narrative of the day",
  "keyPeople": ["list of people mentioned by name"],
  "notableEvents": ["list of 2-5 notable things that happened"],
  "userMoods": ["mood descriptors observed"],
  "decisions": ["any decisions or plans mentioned"]
}

Be specific and personal. The user is documenting their life.
''',
      messages: [
        {
          'role': 'user',
          'content':
              'Date: $date\nSpeakers: $speakerList\n\nTranscript:\n$transcript',
        },
      ],
      maxTokens: AppConstants.maxMemoryTokens,
    );

    // Extract JSON from <json>...</json> tags
    final jsonMatch = RegExp(r'<json>(.*?)</json>', dotAll: true).firstMatch(response);
    final jsonStr = jsonMatch != null
        ? jsonMatch.group(1)!.trim()
        : _extractJsonFallback(response);

    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final now = DateTime.now();
      return MemoryEntry(
        date: date,
        summary: data['summary'] as String? ?? '',
        keyPeople: (data['keyPeople'] as List?)?.cast<String>() ?? [],
        notableEvents: (data['notableEvents'] as List?)?.cast<String>() ?? [],
        userMoods: (data['userMoods'] as List?)?.cast<String>() ?? [],
        decisions: (data['decisions'] as List?)?.cast<String>() ?? [],
        createdAt: now,
        updatedAt: now,
      );
    } catch (_) {
      final now = DateTime.now();
      return MemoryEntry(
        date: date,
        summary: response,
        createdAt: now,
        updatedAt: now,
      );
    }
  }

  // ─── Memory search ─────────────────────────────────────────────────────

  Future<String> searchMemories({
    required String query,
    required List<MemoryEntry> memories,
  }) async {
    final memoryText = memories
        .take(30)
        .map((m) => m.toReadableText())
        .join('\n\n---\n\n');

    return _send(
      systemPrompt: '''
You are SoulSync, answering questions about the user's documented life journey.
Use the memory entries provided to give a personal, insightful answer.
Be specific — reference dates and actual events when relevant.
Keep answers to 2-4 sentences unless detail is clearly needed.
''',
      messages: [
        {
          'role': 'user',
          'content': 'Memory entries:\n$memoryText\n\nQuestion: $query',
        },
      ],
      maxTokens: 512,
    );
  }

  // ─── API key validation ────────────────────────────────────────────────

  Future<bool> validateApiKey(String key) async {
    final prev = _apiKey;
    _apiKey = key;
    try {
      await _send(
        systemPrompt: 'Say: OK',
        messages: [
          {'role': 'user', 'content': 'hi'},
        ],
        maxTokens: 5,
      );
      return true;
    } catch (_) {
      _apiKey = prev;
      return false;
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _extractJsonFallback(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return '{}';
  }
}

extension _ListExt<T> on List<T> {
  List<T> takeLast(int n) =>
      length <= n ? this : sublist(length - n);
}
