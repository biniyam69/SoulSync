import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/speaker_service.dart';

// ─── Infrastructure ────────────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Override in main'),
);

// ─── Settings derived from SharedPreferences ──────────────────────────────

final apiKeyProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(AppConstants.prefApiKey) ?? '';
});

final userNameProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(AppConstants.prefUserName) ?? '';
});

final checkInEnabledProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefCheckInEnabled) ?? true;
});

final onboardingDoneProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
});

// ─── Services ──────────────────────────────────────────────────────────────

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final claudeServiceProvider = Provider<ClaudeService>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  return ClaudeService(apiKey);
});

final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = SpeechService();
  ref.onDispose(service.dispose);
  return service;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

final speakerServiceProvider = Provider<SpeakerService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SpeakerService(storage);
});
