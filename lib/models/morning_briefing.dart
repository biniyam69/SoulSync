class MorningBriefing {
  final String id;
  final String date; // YYYY-MM-DD
  final String content;
  bool dismissed;

  MorningBriefing({
    required this.id,
    required this.date,
    required this.content,
    this.dismissed = false,
  });

  MorningBriefing copyWith({
    String? id,
    String? date,
    String? content,
    bool? dismissed,
  }) =>
      MorningBriefing(
        id: id ?? this.id,
        date: date ?? this.date,
        content: content ?? this.content,
        dismissed: dismissed ?? this.dismissed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'content': content,
        'dismissed': dismissed,
      };

  factory MorningBriefing.fromJson(Map<String, dynamic> json) =>
      MorningBriefing(
        id: json['id'] as String,
        date: json['date'] as String,
        content: json['content'] as String,
        dismissed: json['dismissed'] as bool? ?? false,
      );
}
