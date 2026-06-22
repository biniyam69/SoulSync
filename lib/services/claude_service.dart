import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/transcript_entry.dart';
import '../models/daily_session.dart';
import '../models/memory_entry.dart';
import '../models/intent.dart';
import '../models/person.dart';
import '../models/persona.dart';
import '../models/emotion.dart';
import '../models/introspection_entry.dart';
import '../models/calendar_event_model.dart';
import '../models/email_brief.dart';

class ClaudeService {
  String _apiKey;
  final LlmProvider _provider;
  final String _deepseekApiKey;

  ClaudeService(
    this._apiKey, {
    LlmProvider provider = LlmProvider.claude,
    String deepseekApiKey = '',
  })  : _provider = provider,
        _deepseekApiKey = deepseekApiKey;

  void updateApiKey(String key) => _apiKey = key;

  Future<String> _send({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    int maxTokens = 256,
  }) async {
    return _provider == LlmProvider.deepseek
        ? _sendDeepSeek(systemPrompt: systemPrompt, messages: messages, maxTokens: maxTokens)
        : _sendClaude(systemPrompt: systemPrompt, messages: messages, maxTokens: maxTokens);
  }

  Future<String> _sendClaude({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    required int maxTokens,
  }) async {
    if (_apiKey.isEmpty) throw Exception('Claude API key not set');

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
      throw Exception(_parseApiError(response.body, 'Claude', response.statusCode));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['content'] as List).first['text'] as String;
  }

  Future<String> _sendDeepSeek({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    required int maxTokens,
  }) async {
    if (_deepseekApiKey.isEmpty) throw Exception('DeepSeek API key not set');

    // OpenAI-compatible format: system as first message
    final allMessages = [
      {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];

    final response = await http
        .post(
          Uri.parse('https://api.deepseek.com/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $_deepseekApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'deepseek-chat',
            'max_tokens': maxTokens,
            'messages': allMessages,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseApiError(response.body, 'DeepSeek', response.statusCode));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['choices'][0]['message']['content'] as String;
  }

  // Returns a safe, non-leaking error message from an API error response.
  String _parseApiError(String responseBody, String provider, int statusCode) {
    try {
      final body = jsonDecode(responseBody) as Map<String, dynamic>;
      final msg = body['error']?['message'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
    // Fall back to a generic message that doesn't expose internals
    return '$provider service unavailable. Please try again.';
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

  // ─── Intent extraction ────────────────────────────────────────────────

  Future<String?> extractIntent(String utteranceText, String utteranceId) async {
    if (!Intent.looksLikeIntent(utteranceText)) return null;

    try {
      final result = await _send(
        systemPrompt: '''
Extract the core commitment or task from this statement. Return ONLY the clean task text — no quotes, no explanation.
If there is no clear actionable commitment, return exactly: NONE
Examples:
Input: "I should really call my mom this week" → Output: Call mom
Input: "I need to finish the report by Friday" → Output: Finish the report by Friday
Input: "I'm just saying it would be nice" → Output: NONE
''',
        messages: [{'role': 'user', 'content': utteranceText}],
        maxTokens: 40,
      );
      final clean = result.trim();
      if (clean == 'NONE' || clean.isEmpty) return null;
      return clean;
    } catch (_) {
      return null;
    }
  }

  // ─── Emotion detection ────────────────────────────────────────────────

  Future<EmotionalState> detectEmotion(String text) async {
    // Fast local detection first
    final local = EmotionalState.detectLocal(text);
    if (local != EmotionalState.neutral) return local;

    try {
      final result = await _send(
        systemPrompt: '''
Classify the emotional state in this text with ONE word from this list:
calm, happy, excited, stressed, anxious, sad, frustrated, focused, tired, neutral
Return ONLY the single word.
''',
        messages: [{'role': 'user', 'content': text}],
        maxTokens: 10,
      );
      return EmotionalState.fromString(result.trim());
    } catch (_) {
      return EmotionalState.neutral;
    }
  }

  // ─── Morning briefing ─────────────────────────────────────────────────

  Future<String> generateMorningBriefing({
    required String userName,
    required MemoryEntry? yesterday,
    required List<Intent> openIntents,
    required Persona persona,
    List<CalendarEventModel> calendarEvents = const [],
    List<EmailBrief> emailBriefs = const [],
  }) async {
    final name = userName.isNotEmpty ? userName : 'friend';
    final yesterdaySummary = yesterday?.summary ?? 'No entry for yesterday.';
    final intentsText = openIntents.isEmpty
        ? 'No open commitments.'
        : openIntents
            .take(3)
            .map((i) => '• ${i.text} (${i.ageDays}d old)')
            .join('\n');

    final calendarText = calendarEvents.isEmpty
        ? ''
        : '\n\nToday\'s schedule:\n' +
            calendarEvents
                .map((e) => '• ${e.timeLabel} — ${e.title}${e.location != null ? ' @ ${e.location}' : ''}')
                .join('\n');

    final emailText = emailBriefs.isEmpty
        ? ''
        : '\n\nUnread emails:\n' +
            emailBriefs
                .take(5)
                .map((e) => '• From ${e.from}: "${e.subject}" — ${e.snippet.length > 80 ? '${e.snippet.substring(0, 80)}…' : e.snippet}')
                .join('\n');

    return _send(
      systemPrompt: '''
${persona.systemPromptModifier}
You are giving a morning briefing to $name. Be warm and energizing.
If there are calendar events, mention the important ones naturally. If there are emails that need attention, highlight them briefly.
Keep it to 4-5 sentences total, followed by ONE question to carry into the day.
Speak naturally, not like a report.
''',
      messages: [
        {
          'role': 'user',
          'content':
              'Yesterday: $yesterdaySummary\n\nOpen commitments:\n$intentsText$calendarText$emailText\n\nGive me my morning briefing.',
        },
      ],
      maxTokens: 250,
    );
  }

  // ─── Introspection prompt ─────────────────────────────────────────────

  Future<String> generateIntrospectionQuestion({
    required String userName,
    required List<TranscriptEntry> recentEntries,
    required List<MemoryEntry> recentMemories,
    required Persona persona,
    required EmotionalState currentMood,
  }) async {
    final recentText = recentEntries.isEmpty
        ? 'No recent conversation.'
        : recentEntries
            .take(5)
            .map((e) => '${e.speakerLabel}: ${e.text}')
            .join('\n');

    final memoryThemes = recentMemories.isEmpty
        ? ''
        : recentMemories
            .take(3)
            .map((m) => m.summary)
            .join(' | ');

    return _send(
      systemPrompt: '''
${persona.systemPromptModifier}
Generate ONE deep, personal introspective question for ${userName.isNotEmpty ? userName : 'the user'}.
The question should feel relevant to their current state and recent life.
Do NOT make it generic. Make it specific to what they seem to be going through.
Current mood detected: ${currentMood.label}.
Return ONLY the question. No preamble.
''',
      messages: [
        {
          'role': 'user',
          'content':
              'Recent activity:\n$recentText\n\nRecent memory themes: $memoryThemes\n\nGive me a question to reflect on.',
        },
      ],
      maxTokens: 80,
    );
  }

  // ─── People extraction ────────────────────────────────────────────────

  Future<List<Map<String, String>>> extractPeopleFromSession({
    required DailySession session,
    required String userName,
  }) async {
    if (session.entries.isEmpty) return [];

    final transcript = session.entries
        .where((e) => !e.isAssistant)
        .map((e) => '${e.speakerLabel}: ${e.text}')
        .join('\n');

    try {
      final result = await _send(
        systemPrompt: '''
Extract all real people mentioned by name in this transcript.
For each person, determine: their name, relationship type (friend/family/work/romantic/acquaintance/unknown), and a short 1-sentence context.
Return as JSON inside <json></json> tags.
Format: [{"name": "Alex", "relationship": "friend", "context": "mentioned working together on a project"}]
Do NOT include "$userName" or generic references. Only real named people.
If nobody is mentioned, return: <json>[]</json>
''',
        messages: [{'role': 'user', 'content': transcript}],
        maxTokens: 400,
      );

      final match = RegExp(r'<json>(.*?)</json>', dotAll: true).firstMatch(result);
      final jsonStr = match?.group(1)?.trim() ?? '[]';
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Weekly digest ────────────────────────────────────────────────────

  Future<String> generateWeeklyDigest({
    required String userName,
    required List<MemoryEntry> weekMemories,
    required List<Intent> completedIntents,
    required List<Intent> openIntents,
    required Persona persona,
  }) async {
    final memorySummaries = weekMemories
        .map((m) => '${m.date}: ${m.summary}')
        .join('\n\n');

    final completedText = completedIntents.isEmpty
        ? 'None'
        : completedIntents.map((i) => '✓ ${i.text}').join('\n');
    final openText = openIntents.isEmpty
        ? 'None'
        : openIntents.map((i) => '• ${i.text}').join('\n');

    return _send(
      systemPrompt: '''
${persona.systemPromptModifier}
Generate a weekly digest for ${userName.isNotEmpty ? userName : 'the user'}.
Make it feel like a personal podcast episode — warm, reflective, narrative.
Cover: the week's arc/theme, key moments, who showed up in their life, how they seemed to feel.
End with one insight or encouragement.
Keep it under 300 words. Speak in second person.
''',
      messages: [
        {
          'role': 'user',
          'content':
              'Week memories:\n$memorySummaries\n\nCompleted this week:\n$completedText\n\nStill open:\n$openText\n\nGenerate my weekly digest.',
        },
      ],
      maxTokens: 600,
    );
  }

  // ─── Thought journal summary ──────────────────────────────────────────

  Future<String> summarizeThoughtJournal(List<TranscriptEntry> thoughts) async {
    if (thoughts.isEmpty) return 'Nothing was captured.';

    final text = thoughts.map((t) => t.text).join('\n');

    return _send(
      systemPrompt: '''
The user just finished a private thought journal session — they spoke freely without interruption.
Reflect back what was on their mind. Be observational and gentle.
Identify: main themes, any tensions or excitements, what seemed most present.
Keep it to 2-3 sentences. Speak in second person ("You were thinking about...").
''',
      messages: [{'role': 'user', 'content': text}],
      maxTokens: 150,
    );
  }

  // ─── Insights ─────────────────────────────────────────────────────────

  Future<String> generateWeeklyInsight({
    required List<MemoryEntry> memories,
    required List<TranscriptEntry> recentEntries,
  }) async {
    final memText = memories.take(7).map((m) => m.toReadableText()).join('\n\n---\n\n');

    return _send(
      systemPrompt: '''
You are analyzing a week of someone's life to surface a non-obvious pattern or insight.
Look for: recurring themes, emotional patterns, relationship dynamics, contradictions between stated goals and actual behavior.
Return ONE paragraph — a single, specific, genuinely useful observation.
Not generic advice. A real pattern you see.
''',
      messages: [{'role': 'user', 'content': memText}],
      maxTokens: 200,
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
