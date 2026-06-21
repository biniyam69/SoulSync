import 'transcript_entry.dart';

class DailySession {
  final String date; // YYYY-MM-DD
  final List<TranscriptEntry> entries;
  bool reviewComplete;

  DailySession({
    required this.date,
    List<TranscriptEntry>? entries,
    this.reviewComplete = false,
  }) : entries = entries ?? [];

  Map<String, dynamic> toJson() => {
    'date': date,
    'entries': entries.map((e) => e.toJson()).toList(),
    'reviewComplete': reviewComplete,
  };

  factory DailySession.fromJson(Map<String, dynamic> json) => DailySession(
    date: json['date'] as String,
    entries: (json['entries'] as List<dynamic>? ?? [])
        .map((e) => TranscriptEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    reviewComplete: json['reviewComplete'] as bool? ?? false,
  );

  DailySession copyWith({
    List<TranscriptEntry>? entries,
    bool? reviewComplete,
  }) => DailySession(
    date: date,
    entries: entries ?? List.from(this.entries),
    reviewComplete: reviewComplete ?? this.reviewComplete,
  );

  /// All unique speaker IDs that are not the assistant or user
  List<String> get unknownSpeakers {
    return entries
        .where((e) => !e.isAssistant && e.speakerId != 'user')
        .map((e) => e.speakerId)
        .toSet()
        .toList();
  }

  /// Entries grouped by speaker for review
  Map<String, List<TranscriptEntry>> get entriesBySpeaker {
    final map = <String, List<TranscriptEntry>>{};
    for (final e in entries) {
      map.putIfAbsent(e.speakerId, () => []).add(e);
    }
    return map;
  }
}
