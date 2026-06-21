import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

typedef OnUtteranceComplete = void Function(String text, double soundLevel);
typedef OnPartialResult = void Function(String text);
typedef OnSoundLevel = void Function(double level);

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  bool _isListening = false;
  double _lastSoundLevel = 0;

  OnUtteranceComplete? onUtteranceComplete;
  OnPartialResult? onPartialResult;
  OnSoundLevel? onSoundLevel;

  bool get isListening => _isListening;
  double get lastSoundLevel => _lastSoundLevel;

  Future<bool> initialize() async {
    _available = await _stt.initialize(
      onError: (e) => _isListening = false,
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );
    return _available;
  }

  Future<void> startListening() async {
    if (!_available || _isListening) return;

    _isListening = true;
    await _stt.listen(
      onResult: _onResult,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
      listenOptions: SpeechListenOptions(
        onSoundLevelChange: (level) {
          _lastSoundLevel = level;
          onSoundLevel?.call(level);
        },
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;

    if (result.finalResult) {
      onUtteranceComplete?.call(words, _lastSoundLevel);
    } else {
      onPartialResult?.call(words);
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    await _stt.stop();
  }

  Future<void> cancelListening() async {
    _isListening = false;
    await _stt.cancel();
  }

  /// Called after TTS finishes speaking — restarts listening
  Future<void> restartAfterTts() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await startListening();
  }

  void dispose() {
    _stt.cancel();
  }
}
