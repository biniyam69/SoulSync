# SoulSync

> *Your digital soul — a life companion that listens, remembers, and grows with you.*

SoulSync is a Flutter app that turns your phone + earphones into an always-on life companion. It passively documents your day through continuous speech recognition, proactively checks in on you, captures your commitments, tracks the people you talk about, and synthesises everything into nightly memories — powered by Claude AI.

---

## What it does

| Feature | Description |
|---|---|
| **Always-on listening** | Continuous STT via earphones; auto-restarts every 65s to beat iOS limits |
| **Proactive check-ins** | Asks "what's up?", "what are we working on?" at timed intervals |
| **Emotion detection** | Tags each utterance with an emotional state (local fast-path + Claude API) |
| **Intent capture** | Detects commitments ("I'll call him tomorrow") and tracks them |
| **Morning briefing** | Auto-generates a spoken morning summary between 6–12am |
| **Nightly review** | Reads back the day's transcript; you edit it into a permanent memory |
| **Memory / journal** | Searchable log of past days with mood arc, key people, key events |
| **Thought journal** | Freeform voice or text entries outside the main session |
| **Insights dashboard** | Streak, mood arc, commitment stats, people chips |
| **People / relationships** | Auto-tracks people mentioned; builds a relationship map over time |
| **Introspection** | Periodic deep questions ("what's actually driving that feeling?") |
| **Weekly digest** | Spoken narrative summary of your week, regeneratable |
| **Persona modes** | Best Friend · Life Coach · Silent Witness · Therapist — adjusts tone, check-in frequency, and introspection ratio |
| **Local notifications** | Reminds you of overdue commitments at app open |

---

## Screenshots

> *(Add screenshots here)*

---

## Tech stack

- **Flutter 3 / Dart** — cross-platform iOS + Android
- **Riverpod 2** — state management (`AsyncNotifierProvider`, `NotifierProvider`)
- **Claude API** (`claude-sonnet-4-6`) — all AI generation (check-ins, insights, digest, intent extraction, introspection)
- **speech_to_text** — continuous STT with live amplitude
- **flutter_tts** — TTS playback (coordinates with STT to avoid conflicts)
- **flutter_local_notifications** — overdue commitment reminders
- **path_provider** — JSON file storage (no external DB)
- **shared_preferences** — onboarding state, settings

---

## Setup

### Prerequisites

- Flutter SDK ≥ 3.0
- An [Anthropic API key](https://console.anthropic.com/)
- Xcode (iOS) or Android Studio (Android)

### 1. Clone and install

```bash
git clone https://github.com/biniyam69/SoulSync.git
cd SoulSync
flutter pub get
```

### 2. Add your API key

Open `lib/core/constants.dart` and set your key:

```dart
static const String claudeApiKey = 'sk-ant-...';
```

Or set it from the in-app **Settings → Claude API Key** screen.

### 3. Run

```bash
flutter run
```

For best results, use a real device with a microphone (simulator STT is limited).

---

## Project structure

```
lib/
├── core/           # Theme, colors, app-wide constants
├── models/         # Data models (MemoryEntry, Intent, Person, Persona, …)
├── providers/      # Riverpod providers (soul, intents, people, briefing, …)
├── screens/        # All screens
│   ├── home_screen.dart          # Orb + live transcript + drawer
│   ├── nightly_review_screen.dart
│   ├── memory_screen.dart
│   ├── insights_screen.dart
│   ├── intents_screen.dart
│   ├── thought_journal_screen.dart
│   ├── relationships_screen.dart
│   ├── introspection_screen.dart
│   ├── morning_briefing_screen.dart
│   ├── weekly_digest_screen.dart
│   └── settings_screen.dart
├── services/       # Claude API, TTS, STT, storage, notifications
└── widgets/        # SoulOrb, TranscriptTile, WaveformWidget
```

---

## Navigation

Swipe right from the home screen to open the drawer:

```
Today  ·  Insights  ·  Commitments  ·  Thought Journal
People  ·  Reflections  ·  Memory  ·  Weekly Digest
Nightly Review  ·  Settings
```

---

## Persona modes

Select in **Settings**:

| Persona | Check-in rate | Introspection | Style |
|---|---|---|---|
| Best Friend | Normal | 20% | Warm, casual |
| Life Coach | 1.5× | 40% | Motivating, structured |
| Silent Witness | Off | 0% | Purely documents, never speaks first |
| Therapist | 0.7× | 60% | Reflective, open questions |

---

## Permissions

The app requests:

- **Microphone** — continuous speech recognition
- **Notifications** — overdue commitment reminders

---

## License

MIT
