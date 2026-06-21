import 'dart:math';
import '../models/speaker.dart';
import 'storage_service.dart';

class SpeakerService {
  final StorageService _storage;
  List<Speaker> _profiles = [];
  bool _loaded = false;

  static const double _matchThreshold = 12.0; // sound level distance threshold
  static const String _unknownPrefix = 'person_';

  SpeakerService(this._storage);

  Future<void> load() async {
    if (_loaded) return;
    _profiles = await _storage.loadSpeakers();

    // Ensure user profile exists
    if (!_profiles.any((s) => s.id == SpeakerIds.user)) {
      _profiles.add(Speaker(
        id: SpeakerIds.user,
        name: 'You',
        isUser: true,
        enrolledAt: DateTime.now(),
      ));
    }
    _loaded = true;
  }

  Future<void> save() => _storage.saveSpeakers(_profiles);

  List<Speaker> get profiles => List.unmodifiable(_profiles);

  Speaker? get userProfile =>
      _profiles.where((s) => s.id == SpeakerIds.user).firstOrNull;

  /// Enrolls the user's voice from a list of sound level samples (from onboarding)
  Future<void> enrollUser(List<double> soundLevels) async {
    await load();
    if (soundLevels.isEmpty) return;
    final avg = soundLevels.reduce((a, b) => a + b) / soundLevels.length;
    final variance = soundLevels.fold<double>(
          0,
          (prev, x) => prev + pow(x - avg, 2),
        ) /
        soundLevels.length;

    final profile = _profiles.firstWhere(
      (s) => s.id == SpeakerIds.user,
      orElse: () {
        final p = Speaker(
          id: SpeakerIds.user,
          name: 'You',
          isUser: true,
          enrolledAt: DateTime.now(),
        );
        _profiles.add(p);
        return p;
      },
    );

    profile.voiceSignature = [avg, sqrt(variance)];
    await save();
  }

  /// Identifies speaker by sound level. Returns speaker ID.
  String identifySpeaker(double soundLevel) {
    if (_profiles.isEmpty) return SpeakerIds.unknown;

    // Check user profile first
    final user = userProfile;
    if (user != null && user.voiceSignature.isNotEmpty) {
      final distance = (soundLevel - user.voiceSignature[0]).abs();
      if (distance < _matchThreshold) return SpeakerIds.user;
    }

    // Check other enrolled profiles
    Speaker? bestMatch;
    double bestDist = _matchThreshold;
    for (final profile in _profiles.where((s) => !s.isUser)) {
      if (profile.voiceSignature.isEmpty) continue;
      final dist = (soundLevel - profile.voiceSignature[0]).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestMatch = profile;
      }
    }

    if (bestMatch != null) {
      _updateProfile(bestMatch.id, soundLevel);
      return bestMatch.id;
    }

    // Create a new unknown person profile
    return _createNewPerson(soundLevel);
  }

  String _createNewPerson(double soundLevel) {
    final existing = _profiles
        .where((s) => s.id.startsWith(_unknownPrefix))
        .length;
    final id = '$_unknownPrefix${existing + 1}';
    final profile = Speaker(
      id: id,
      name: 'Person ${existing + 1}',
      isUser: false,
      enrolledAt: DateTime.now(),
      voiceSignature: [soundLevel],
    );
    _profiles.add(profile);
    save(); // Fire and forget
    return id;
  }

  void _updateProfile(String id, double soundLevel) {
    final idx = _profiles.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final p = _profiles[idx];
    if (p.voiceSignature.isEmpty) {
      p.voiceSignature = [soundLevel];
    } else {
      // Exponential moving average
      p.voiceSignature[0] = 0.9 * p.voiceSignature[0] + 0.1 * soundLevel;
    }
  }

  Future<void> renameSpeaker(String id, String newName) async {
    await load();
    final idx = _profiles.indexWhere((s) => s.id == id);
    if (idx != -1) _profiles[idx].name = newName;
    await save();
  }

  Future<void> deleteSpeaker(String id) async {
    if (id == SpeakerIds.user) return; // Never delete user
    _profiles.removeWhere((s) => s.id == id);
    await save();
  }

  String speakerLabel(String speakerId) {
    if (speakerId == SpeakerIds.assistant) return 'SoulSync';
    if (speakerId == SpeakerIds.unknown) return 'Unknown';
    return _profiles
            .where((s) => s.id == speakerId)
            .firstOrNull
            ?.name ??
        speakerId;
  }
}
