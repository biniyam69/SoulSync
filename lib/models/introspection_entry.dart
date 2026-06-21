import 'emotion.dart';

class IntrospectionEntry {
  final String id;
  final DateTime date;
  final String question;
  String answer;
  final EmotionalState mood;
  List<String> tags;

  IntrospectionEntry({
    required this.id,
    required this.date,
    required this.question,
    this.answer = '',
    this.mood = EmotionalState.neutral,
    List<String>? tags,
  }) : tags = tags ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'question': question,
    'answer': answer,
    'mood': mood.label,
    'tags': tags,
  };

  factory IntrospectionEntry.fromJson(Map<String, dynamic> json) =>
      IntrospectionEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        question: json['question'] as String,
        answer: json['answer'] as String? ?? '',
        mood: EmotionalState.fromString(json['mood'] as String? ?? 'neutral'),
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}
