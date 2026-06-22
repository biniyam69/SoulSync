enum EmotionalState {
  calm,
  happy,
  excited,
  stressed,
  anxious,
  sad,
  frustrated,
  focused,
  tired,
  neutral,
}

extension EmotionalStateExt on EmotionalState {
  String get label {
    switch (this) {
      case EmotionalState.calm: return 'calm';
      case EmotionalState.happy: return 'happy';
      case EmotionalState.excited: return 'excited';
      case EmotionalState.stressed: return 'stressed';
      case EmotionalState.anxious: return 'anxious';
      case EmotionalState.sad: return 'sad';
      case EmotionalState.frustrated: return 'frustrated';
      case EmotionalState.focused: return 'focused';
      case EmotionalState.tired: return 'tired';
      case EmotionalState.neutral: return 'neutral';
    }
  }

  // Color hex values (not Flutter Color — avoid needing flutter import in models)
  int get colorValue {
    switch (this) {
      case EmotionalState.calm: return 0xFF4A9EFF;      // blue
      case EmotionalState.happy: return 0xFFFFD60A;     // yellow
      case EmotionalState.excited: return 0xFFFF9F0A;   // orange
      case EmotionalState.stressed: return 0xFFFF453A;  // red
      case EmotionalState.anxious: return 0xFFBF5AF2;   // purple
      case EmotionalState.sad: return 0xFF64D2FF;       // light blue
      case EmotionalState.frustrated: return 0xFFFF6961; // salmon
      case EmotionalState.focused: return 0xFF30D158;   // green
      case EmotionalState.tired: return 0xFF636366;     // grey
      case EmotionalState.neutral: return 0xFF8E8E93;   // mid grey
    }
  }

  String get emoji {
    switch (this) {
      case EmotionalState.calm: return '😌';
      case EmotionalState.happy: return '😊';
      case EmotionalState.excited: return '🔥';
      case EmotionalState.stressed: return '😤';
      case EmotionalState.anxious: return '😰';
      case EmotionalState.sad: return '😔';
      case EmotionalState.frustrated: return '😠';
      case EmotionalState.focused: return '🎯';
      case EmotionalState.tired: return '😴';
      case EmotionalState.neutral: return '😐';
    }
  }

  factory EmotionalState.fromString(String s) {
    return EmotionalState.values.firstWhere(
      (e) => e.label == s.toLowerCase().trim(),
      orElse: () => EmotionalState.neutral,
    );
  }

  // Quick keyword-based local detection (no API call needed for common cases)
  static EmotionalState detectLocal(String text) {
    final t = text.toLowerCase();

    final stressWords = ['stress', 'overwhelm', 'can\'t handle', 'too much', 'deadline', 'behind', 'panic', 'ugh'];
    final happyWords = ['great', 'amazing', 'awesome', 'love', 'wonderful', 'happy', 'excited', 'yes!', 'finally'];
    final sadWords = ['sad', 'miss', 'lost', 'tired', 'depressed', 'lonely', 'disappoint', 'fail'];
    final focusWords = ['working on', 'coding', 'building', 'writing', 'focus', 'deep work', 'almost done'];
    final excitedWords = ['can\'t wait', 'so excited', 'incredible', 'blown away', 'perfect', '!!'];
    final anxiousWords = ['worried', 'nervous', 'anxious', 'scared', 'what if', 'not sure'];
    final tiredWords = ['tired', 'exhausted', 'sleepy', 'drained', 'need sleep', 'so tired'];

    if (excitedWords.any(t.contains)) return EmotionalState.excited;
    if (happyWords.any(t.contains)) return EmotionalState.happy;
    if (stressWords.any(t.contains)) return EmotionalState.stressed;
    if (anxiousWords.any(t.contains)) return EmotionalState.anxious;
    if (sadWords.any(t.contains)) return EmotionalState.sad;
    if (focusWords.any(t.contains)) return EmotionalState.focused;
    if (tiredWords.any(t.contains)) return EmotionalState.tired;
    return EmotionalState.neutral;
  }
}
