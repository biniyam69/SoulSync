import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/persona.dart';
import 'app_providers.dart';

const _prefPersona = 'persona_mode';

class PersonaNotifier extends Notifier<Persona> {
  late SharedPreferences _prefs;

  @override
  Persona build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final saved = _prefs.getString(_prefPersona);
    return saved != null ? Persona.fromString(saved) : Persona.bestFriend;
  }

  Future<void> setPersona(Persona persona) async {
    await _prefs.setString(_prefPersona, persona.name);
    state = persona;
  }
}

final personaProvider = NotifierProvider<PersonaNotifier, Persona>(
  PersonaNotifier.new,
);
