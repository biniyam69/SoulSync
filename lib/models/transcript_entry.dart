class TranscriptEntry {
  final String id;
  final DateTime timestamp;
  final String text;
  final String speakerId;
  String speakerLabel;
  final bool isAssistant;

  TranscriptEntry({
    required this.id,
    required this.timestamp,
    required this.text,
    required this.speakerId,
    required this.speakerLabel,
    this.isAssistant = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'text': text,
    'speakerId': speakerId,
    'speakerLabel': speakerLabel,
    'isAssistant': isAssistant,
  };

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) =>
      TranscriptEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        text: json['text'] as String,
        speakerId: json['speakerId'] as String,
        speakerLabel: json['speakerLabel'] as String,
        isAssistant: json['isAssistant'] as bool? ?? false,
      );

  TranscriptEntry copyWith({String? speakerLabel}) => TranscriptEntry(
    id: id,
    timestamp: timestamp,
    text: text,
    speakerId: speakerId,
    speakerLabel: speakerLabel ?? this.speakerLabel,
    isAssistant: isAssistant,
  );
}
