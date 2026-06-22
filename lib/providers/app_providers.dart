import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

// ─── Secure API key state (initialized from secure storage in main.dart) ──

// These start empty; main.dart overrides them with values loaded from
// FlutterSecureStorage (with one-time migration from SharedPreferences).
final apiKeyProvider = StateProvider<String>((_) => '');
final deepseekApiKeyProvider = StateProvider<String>((_) => '');
final elevenlabsApiKeyProvider = StateProvider<String>((_) => '');
final elevenlabsVoiceIdProvider = StateProvider<String>((_) => '');

// ─── Non-sensitive settings from SharedPreferences ─────────────────────────

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

final llmProviderProvider = Provider<LlmProvider>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final str = prefs.getString(AppConstants.prefLlmProvider) ?? 'claude';
  return str == 'deepseek' ? LlmProvider.deepseek : LlmProvider.claude;
});

// ─── Services ──────────────────────────────────────────────────────────────

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final claudeServiceProvider = Provider<ClaudeService>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  final provider = ref.watch(llmProviderProvider);
  final deepseekKey = ref.watch(deepseekApiKeyProvider);
  return ClaudeService(apiKey, provider: provider, deepseekApiKey: deepseekKey);
});

final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = SpeechService();
  ref.onDispose(service.dispose);
  return service;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final elKey = ref.watch(elevenlabsApiKeyProvider);
  final voiceId = ref.watch(elevenlabsVoiceIdProvider);
  final service = TtsService(elevenlabsApiKey: elKey, voiceId: voiceId);
  ref.onDispose(service.dispose);
  return service;
});

final speakerServiceProvider = Provider<SpeakerService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SpeakerService(storage);
});
