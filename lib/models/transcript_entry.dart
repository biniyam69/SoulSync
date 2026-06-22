import 'emotion.dart';

enum EntryType { conversation, thought, briefing }

class TranscriptEntry {
  final String id;
  final DateTime timestamp;
  final String text;
  final String speakerId;
  String speakerLabel;
  final bool isAssistant;
  EmotionalState? emotion;
  EntryType type;

  TranscriptEntry({
    required this.id,
    required this.timestamp,
    required this.text,
    required this.speakerId,
    required this.speakerLabel,
    this.isAssistant = false,
    this.emotion,
    this.type = EntryType.conversation,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'text': text,
    'speakerId': speakerId,
    'speakerLabel': speakerLabel,
    'isAssistant': isAssistant,
    'emotion': emotion?.label,
    'type': type.name,
  };

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) =>
      TranscriptEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        text: json['text'] as String,
        speakerId: json['speakerId'] as String,
        speakerLabel: json['speakerLabel'] as String,
        isAssistant: json['isAssistant'] as bool? ?? false,
        emotion: json['emotion'] != null
            ? EmotionalState.fromString(json['emotion'] as String)
            : null,
        type: EntryType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => EntryType.conversation,
        ),
      );

  TranscriptEntry copyWith({
    String? speakerLabel,
    EmotionalState? emotion,
    EntryType? type,
  }) =>
      TranscriptEntry(
        id: id,
        timestamp: timestamp,
        text: text,
        speakerId: speakerId,
        speakerLabel: speakerLabel ?? this.speakerLabel,
        isAssistant: isAssistant,
        emotion: emotion ?? this.emotion,
        type: type ?? this.type,
      );
}
