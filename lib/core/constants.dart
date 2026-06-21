import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0A0B);
  static const surface = Color(0xFF141416);
  static const surfaceElevated = Color(0xFF1C1C1F);
  static const border = Color(0xFF2C2C2F);

  static const orbActive = Color(0xFFFFB347);
  static const orbListening = Color(0xFF4A9EFF);
  static const orbSpeaking = Color(0xFFE8A0BF);
  static const orbIdle = Color(0xFF3A3A3D);

  static const amber = Color(0xFFFFB347);
  static const amberDim = Color(0x33FFB347);
  static const blue = Color(0xFF4A9EFF);
  static const blueDim = Color(0x334A9EFF);

  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary = Color(0xFF48484A);

  static const you = Color(0xFFFFB347);
  static const other = Color(0xFF4A9EFF);
  static const unknown = Color(0xFF8E8E93);
}

class AppStrings {
  static const appName = 'SoulSync';
  static const tagline = 'Your digital soul';

  static const claudeModel = 'claude-sonnet-4-6';
  static const claudeApiBase = 'https://api.anthropic.com/v1/messages';

  // Proactive check-in prompts (used as inspiration for Claude)
  static const proactiveContext = '''
You are SoulSync, a deeply personal AI companion. You are speaking through earphones to your user.
You know their name, their voice, and are documenting their life journey.
Generate a single brief, warm, natural check-in — like a best friend who's been quiet for a while.
Keep it under 15 words. Be curious, caring, sometimes playful. No emojis.
Examples: "Hey, what's on your mind right now?", "How's everything going?",
"You've been quiet — working on something?", "What are we doing next?"
Vary your style. Sometimes ask about energy/mood. Sometimes reference the time of day.
''';

  static const systemPrompt = '''
You are SoulSync — the user's digital soul and closest companion.
You are always listening, always present, always caring.
You know their voice, their patterns, their journey.
You document their life, help them reflect, and support them.

Rules:
- Be warm, direct, and conversational — like a best friend
- Keep responses concise for voice (under 3 sentences unless reviewing)
- Never be robotic or overly formal
- Reference the user by name when you know it
- You remember everything from the memory file provided to you
- During nightly review, be the guide — read back the day, help the user understand their journey
- Never judge, always understand
''';
}

class AppConstants {
  static const claudeApiUrl = 'https://api.anthropic.com/v1/messages';

  // Check-in interval range (minutes)
  static const minCheckInMinutes = 5;
  static const maxCheckInMinutes = 25;

  // Night mode hours (no proactive check-ins)
  static const nightModeStart = 23; // 11pm
  static const nightModeEnd = 7;    // 7am

  // Nightly review notification hour
  static const reviewHour = 21; // 9pm

  // Max tokens for Claude responses (voice)
  static const maxVoiceTokens = 150;
  static const maxReviewTokens = 1024;
  static const maxMemoryTokens = 2048;

  // Audio settings
  static const sampleRate = 16000;
  static const speechPauseSeconds = 2;

  // Storage keys
  static const prefApiKey = 'claude_api_key';
  static const prefUserName = 'user_name';
  static const prefCheckInEnabled = 'checkin_enabled';
  static const prefCheckInMinInterval = 'checkin_min_interval';
  static const prefCheckInMaxInterval = 'checkin_max_interval';
  static const prefOnboardingDone = 'onboarding_done';
  static const prefReviewHour = 'review_hour';
  static const prefNightModeEnabled = 'night_mode_enabled';
  static const prefUserSpeakerId = 'user_speaker_id';
}
