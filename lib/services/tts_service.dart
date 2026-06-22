import 'dart:async';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final String _elevenlabsApiKey;
  final String _voiceId;

  bool _isSpeaking = false;
  Completer<void>? _speakCompleter;

  final _speakingController = StreamController<bool>.broadcast();

  bool get isSpeaking => _isSpeaking;
  Stream<bool> get speakingStream => _speakingController.stream;

  bool get _useElevenLabs =>
      _elevenlabsApiKey.isNotEmpty && _voiceId.isNotEmpty;

  TtsService({String elevenlabsApiKey = '', String voiceId = ''})
      : _elevenlabsApiKey = elevenlabsApiKey,
        _voiceId = voiceId {
    _initFlutterTts();
    _initAudioPlayer();
  }

  void _initFlutterTts() {
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.48);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);

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

  void _initAudioPlayer() {
    _audioPlayer.onPlayerComplete.listen((_) {
      _isSpeaking = false;
      _speakingController.add(false);
      _speakCompleter?.complete();
      _speakCompleter = null;
    });
  }

  Future<void> initialize() async {
    // flutter_tts is configured in constructor; nothing async needed
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await stop();

    if (_useElevenLabs) {
      await _speakElevenLabs(text.trim());
    } else {
      await _speakFlutterTts(text.trim());
    }
  }

  Future<void> _speakFlutterTts(String text) async {
    _speakCompleter = Completer<void>();
    await _tts.speak(text);
    await _speakCompleter!.future;
  }

  Future<void> _speakElevenLabs(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse(
                'https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'),
            headers: {
              'xi-api-key': _elevenlabsApiKey,
              'Content-Type': 'application/json',
              'Accept': 'audio/mpeg',
            },
            body: '{"text":${_jsonString(text)},'
                '"model_id":"eleven_monolingual_v1",'
                '"voice_settings":{"stability":0.5,"similarity_boost":0.75}}',
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        // Fall back to flutter_tts on API error
        await _speakFlutterTts(text);
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/el_tts.mp3');
      await file.writeAsBytes(response.bodyBytes);

      _speakCompleter = Completer<void>();
      _isSpeaking = true;
      _speakingController.add(true);
      await _audioPlayer.play(DeviceFileSource(file.path));
      await _speakCompleter!.future;
    } catch (_) {
      // Fall back to flutter_tts on any error
      await _speakFlutterTts(text);
    }
  }

  // Minimal JSON string escaping
  String _jsonString(String s) {
    final escaped = s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
    return '"$escaped"';
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
    await _audioPlayer.stop();
    _isSpeaking = false;
    _speakingController.add(false);
    _speakCompleter?.complete();
    _speakCompleter = null;
  }

  void dispose() {
    _speakingController.close();
    _audioPlayer.dispose();
  }
}
