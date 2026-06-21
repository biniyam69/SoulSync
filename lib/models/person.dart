enum Relationship { friend, family, work, romantic, acquaintance, unknown }

class Person {
  final String id;
  String name;
  Relationship relationship;
  final DateTime firstMentionedAt;
  DateTime lastMentionedAt;
  int mentionCount;
  List<String> contextSnippets; // recent short quotes mentioning them
  String notes; // user-written notes

  Person({
    required this.id,
    required this.name,
    this.relationship = Relationship.unknown,
    required this.firstMentionedAt,
    required this.lastMentionedAt,
    this.mentionCount = 1,
    List<String>? contextSnippets,
    this.notes = '',
  }) : contextSnippets = contextSnippets ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relationship': relationship.name,
    'firstMentionedAt': firstMentionedAt.toIso8601String(),
    'lastMentionedAt': lastMentionedAt.toIso8601String(),
    'mentionCount': mentionCount,
    'contextSnippets': contextSnippets,
    'notes': notes,
  };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id'] as String,
    name: json['name'] as String,
    relationship: Relationship.values.firstWhere(
      (r) => r.name == json['relationship'],
      orElse: () => Relationship.unknown,
    ),
    firstMentionedAt: DateTime.parse(json['firstMentionedAt'] as String),
    lastMentionedAt: DateTime.parse(json['lastMentionedAt'] as String),
    mentionCount: json['mentionCount'] as int? ?? 1,
    contextSnippets:
        (json['contextSnippets'] as List<dynamic>?)?.cast<String>() ?? [],
    notes: json['notes'] as String? ?? '',
  );

  String get relationshipLabel {
    switch (relationship) {
      case Relationship.friend: return 'Friend';
      case Relationship.family: return 'Family';
      case Relationship.work: return 'Work';
      case Relationship.romantic: return 'Partner';
      case Relationship.acquaintance: return 'Acquaintance';
      case Relationship.unknown: return 'Person';
    }
  }
}
