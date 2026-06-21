import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  Completer<void>? _speakCompleter;

  bool get isSpeaking => _isSpeaking;

  final _speakingController = StreamController<bool>.broadcast();
  Stream<bool> get speakingStream => _speakingController.stream;

  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
      _speakingController.add(true);
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _speakingController.add(false);
      _speakCompleter?.complete();
      _speakCompleter = null;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _speakingController.add(false);
      _speakCompleter?.complete();
      _speakCompleter = null;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      _speakingController.add(false);
      _speakCompleter?.completeError(msg);
      _speakCompleter = null;
    });
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await stop();
    _speakCompleter = Completer<void>();
    await _tts.speak(text.trim());
    await _speakCompleter!.future;
  }

  Future<void> speakSequence(List<String> sentences) async {
    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) continue;
      await speak(sentence);
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> stop() async {
    if (!_isSpeaking) return;
    await _tts.stop();
    _isSpeaking = false;
    _speakingController.add(false);
    _speakCompleter?.complete();
    _speakCompleter = null;
  }

  void dispose() {
    _speakingController.close();
  }
}
