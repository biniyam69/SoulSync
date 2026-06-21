class Speaker {
  final String id;
  String name;
  bool isUser;
  final DateTime enrolledAt;
  List<double> voiceSignature; // amplitude variance samples for voice ID

  Speaker({
    required this.id,
    required this.name,
    this.isUser = false,
    required this.enrolledAt,
    List<double>? voiceSignature,
  }) : voiceSignature = voiceSignature ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isUser': isUser,
    'enrolledAt': enrolledAt.toIso8601String(),
    'voiceSignature': voiceSignature,
  };

  factory Speaker.fromJson(Map<String, dynamic> json) => Speaker(
    id: json['id'] as String,
    name: json['name'] as String,
    isUser: json['isUser'] as bool? ?? false,
    enrolledAt: DateTime.parse(json['enrolledAt'] as String),
    voiceSignature: (json['voiceSignature'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [],
  );
}

// Built-in speaker IDs
class SpeakerIds {
  static const assistant = 'assistant';
  static const unknown = 'unknown';
  static const user = 'user';
}
