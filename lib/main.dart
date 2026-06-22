import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/constants.dart';
import 'providers/app_providers.dart';
import 'services/notification_service.dart';

// Reads a key from secure storage; if absent, migrates the value from
// SharedPreferences (writes to secure, removes from prefs) and returns it.
Future<String> _loadSecureKey(
  FlutterSecureStorage secure,
  SharedPreferences prefs,
  String key,
) async {
  final stored = await secure.read(key: key);
  if (stored != null && stored.isNotEmpty) return stored;

  final legacy = prefs.getString(key) ?? '';
  if (legacy.isNotEmpty) {
    await secure.write(key: key, value: legacy);
    await prefs.remove(key);
  }
  return legacy;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A0B),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await NotificationService.init();

  final prefs = await SharedPreferences.getInstance();
  const secure = FlutterSecureStorage();

  final claudeKey =
      await _loadSecureKey(secure, prefs, AppConstants.prefApiKey);
  final deepseekKey =
      await _loadSecureKey(secure, prefs, AppConstants.prefDeepSeekApiKey);
  final elKey =
      await _loadSecureKey(secure, prefs, AppConstants.prefElevenLabsApiKey);
  final elVoiceId =
      await _loadSecureKey(secure, prefs, AppConstants.prefElevenLabsVoiceId);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiKeyProvider.overrideWith((ref) => claudeKey),
        deepseekApiKeyProvider.overrideWith((ref) => deepseekKey),
        elevenlabsApiKeyProvider.overrideWith((ref) => elKey),
        elevenlabsVoiceIdProvider.overrideWith((ref) => elVoiceId),
      ],
      child: const SoulSyncApp(),
    ),
  );
}
