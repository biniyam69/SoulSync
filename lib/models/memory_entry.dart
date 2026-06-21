class MemoryEntry {
  final String date; // YYYY-MM-DD
  String summary;
  List<String> keyPeople;
  List<String> notableEvents;
  List<String> userMoods;
  List<String> decisions;
  String rawNotes;
  final DateTime createdAt;
  DateTime updatedAt;

  MemoryEntry({
    required this.date,
    required this.summary,
    List<String>? keyPeople,
    List<String>? notableEvents,
    List<String>? userMoods,
    List<String>? decisions,
    this.rawNotes = '',
    required this.createdAt,
    required this.updatedAt,
  })  : keyPeople = keyPeople ?? [],
        notableEvents = notableEvents ?? [],
        userMoods = userMoods ?? [],
        decisions = decisions ?? [];

  Map<String, dynamic> toJson() => {
    'date': date,
    'summary': summary,
    'keyPeople': keyPeople,
    'notableEvents': notableEvents,
    'userMoods': userMoods,
    'decisions': decisions,
    'rawNotes': rawNotes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) => MemoryEntry(
    date: json['date'] as String,
    summary: json['summary'] as String? ?? '',
    keyPeople: (json['keyPeople'] as List<dynamic>?)?.cast<String>() ?? [],
    notableEvents:
        (json['notableEvents'] as List<dynamic>?)?.cast<String>() ?? [],
    userMoods: (json['userMoods'] as List<dynamic>?)?.cast<String>() ?? [],
    decisions: (json['decisions'] as List<dynamic>?)?.cast<String>() ?? [],
    rawNotes: json['rawNotes'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  String toReadableText() {
    final buf = StringBuffer();
    buf.writeln('Date: $date');
    if (summary.isNotEmpty) buf.writeln('\nSummary:\n$summary');
    if (keyPeople.isNotEmpty) buf.writeln('\nKey People: ${keyPeople.join(', ')}');
    if (notableEvents.isNotEmpty) {
      buf.writeln('\nNotable Events:');
      for (final e in notableEvents) buf.writeln('• $e');
    }
    if (userMoods.isNotEmpty) buf.writeln('\nMood: ${userMoods.join(', ')}');
    if (decisions.isNotEmpty) {
      buf.writeln('\nDecisions:');
      for (final d in decisions) buf.writeln('• $d');
    }
    if (rawNotes.isNotEmpty) buf.writeln('\nNotes:\n$rawNotes');
    return buf.toString().trim();
  }
}
