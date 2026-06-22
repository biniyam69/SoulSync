enum IntentStatus { open, done, dismissed, snoozed }

class Intent {
  final String id;
  String text;           // clean extracted commitment
  final String rawText;  // original utterance it came from
  final String sourceEntryId;
  final DateTime createdAt;
  IntentStatus status;
  DateTime? completedAt;
  DateTime? reminderAt;

  Intent({
    required this.id,
    required this.text,
    required this.rawText,
    required this.sourceEntryId,
    required this.createdAt,
    this.status = IntentStatus.open,
    this.completedAt,
    this.reminderAt,
  });

  bool get isOpen => status == IntentStatus.open;
  bool get isDone => status == IntentStatus.done;

  int get ageDays =>
      DateTime.now().difference(createdAt).inDays;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'rawText': rawText,
    'sourceEntryId': sourceEntryId,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'completedAt': completedAt?.toIso8601String(),
    'reminderAt': reminderAt?.toIso8601String(),
  };

  factory Intent.fromJson(Map<String, dynamic> json) => Intent(
    id: json['id'] as String,
    text: json['text'] as String,
    rawText: json['rawText'] as String? ?? '',
    sourceEntryId: json['sourceEntryId'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: IntentStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => IntentStatus.open,
    ),
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null,
    reminderAt: json['reminderAt'] != null
        ? DateTime.parse(json['reminderAt'] as String)
        : null,
  );

  // Regex patterns that signal an intent
  static final _triggerPatterns = RegExp(
    r'\b(i should|i need to|i have to|i\'m going to|i am going to|'
    r'remind me|i want to|i\'ll|i plan to|i gotta|i got to|'
    r'i must|i\'ve been meaning to|make sure i|don\'t forget)\b',
    caseSensitive: false,
  );

  static bool looksLikeIntent(String text) =>
      _triggerPatterns.hasMatch(text);
}
