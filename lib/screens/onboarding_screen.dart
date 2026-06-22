import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';
import '../providers/app_providers.dart';
import '../services/speaker_service.dart';
import '../services/speech_service.dart';
import '../widgets/soul_orb.dart';
import '../widgets/waveform_widget.dart';
import '../providers/soul_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // API key page
  final _apiKeyCtrl = TextEditingController();
  bool _validatingKey = false;
  bool _keyValid = false;
  String? _keyError;

  // Name page
  final _nameCtrl = TextEditingController();

  // Voice enrollment
  bool _enrolling = false;
  bool _enrollmentDone = false;
  double _soundLevel = 0;
  int _secondsLeft = 10;
  Timer? _enrollTimer;
  final List<double> _soundSamples = [];
  SpeechService? _enrollSpeech;

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyCtrl.dispose();
    _nameCtrl.dispose();
    _enrollTimer?.cancel();
    _enrollSpeech?.dispose();
    super.dispose();
  }

  Future<void> _validateApiKey() async {
    setState(() {
      _validatingKey = true;
      _keyError = null;
    });
    final claude = ref.read(claudeServiceProvider);
    final key = _apiKeyCtrl.text.trim();
    final valid = await claude.validateApiKey(key);
    if (valid) {
      final secure = ref.read(secureStorageProvider);
      await secure.write(key: AppConstants.prefApiKey, value: key);
      ref.read(apiKeyProvider.notifier).state = key;
    }
    setState(() {
      _validatingKey = false;
      _keyValid = valid;
      _keyError = valid ? null : 'Invalid key. Check your Anthropic console.';
    });
    if (valid) _nextPage();
  }

  Future<void> _startEnrollment() async {
    final micStatus = await Permission.microphone.request();
    final speechStatus = await Permission.speech.request();

    if (!micStatus.isGranted || !speechStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required')),
      );
      return;
    }

    setState(() {
      _enrolling = true;
      _secondsLeft = 10;
      _soundSamples.clear();
    });

    _enrollSpeech = SpeechService();
    await _enrollSpeech!.initialize();
    _enrollSpeech!.onSoundLevel = (level) {
      if (!mounted) return;
      setState(() {
        _soundLevel = level;
        _soundSamples.add(level);
      });
    };
    await _enrollSpeech!.startListening();

    _enrollTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        await _finishEnrollment();
      }
    });
  }

  Future<void> _finishEnrollment() async {
    await _enrollSpeech?.stopListening();
    _enrollSpeech?.dispose();
    _enrollSpeech = null;

    final speakers = ref.read(speakerServiceProvider);
    await speakers.enrollUser(_soundSamples);

    if (!mounted) return;
    setState(() {
      _enrolling = false;
      _enrollmentDone = true;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(AppConstants.prefUserName, _nameCtrl.text.trim());
    await prefs.setBool(AppConstants.prefOnboardingDone, true);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentPage = i),
        children: [
          _WelcomePage(onNext: _nextPage),
          _ApiKeyPage(
            ctrl: _apiKeyCtrl,
            validating: _validatingKey,
            valid: _keyValid,
            error: _keyError,
            onValidate: _validateApiKey,
          ),
          _NamePage(
            ctrl: _nameCtrl,
            onNext: _nextPage,
          ),
          _VoicePage(
            enrolling: _enrolling,
            done: _enrollmentDone,
            secondsLeft: _secondsLeft,
            soundLevel: _soundLevel,
            onStart: _startEnrollment,
            onComplete: _completeOnboarding,
          ),
        ],
      ),
    );
  }
}

// ─── Welcome Page ──────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Spacer(),
            SoulOrb(
              phase: AppPhase.idle,
              size: 160,
            ),
            const SizedBox(height: 40),
            Text(
              'SoulSync',
              style: GoogleFonts.inter(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your digital soul',
              style: GoogleFonts.inter(
                fontSize: 17,
                color: AppColors.amber,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 48),
            _FeatureRow(
                icon: Icons.hearing_rounded,
                text: 'Always listening through your earphones'),
            const SizedBox(height: 16),
            _FeatureRow(
                icon: Icons.record_voice_over_rounded,
                text: 'Checks in on you like a best friend'),
            const SizedBox(height: 16),
            _FeatureRow(
                icon: Icons.auto_stories_rounded,
                text: 'Documents your life journey every day'),
            const Spacer(),
            _PrimaryButton(label: "Let's begin", onTap: onNext),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.amberDim,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.amber),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── API Key Page ──────────────────────────────────────────────────────────

class _ApiKeyPage extends StatelessWidget {
  final TextEditingController ctrl;
  final bool validating;
  final bool valid;
  final String? error;
  final VoidCallback onValidate;

  const _ApiKeyPage({
    required this.ctrl,
    required this.validating,
    required this.valid,
    required this.error,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              'Connect your AI',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'SoulSync uses Claude AI as its brain. Enter your Anthropic API key to get started.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get your key at console.anthropic.com',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: ctrl,
              obscureText: true,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'sk-ant-...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.border, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.amber, width: 1),
                ),
                suffixIcon: valid
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF30D158))
                    : null,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 24),
            _PrimaryButton(
              label: validating ? 'Verifying...' : 'Verify & Continue',
              onTap: validating ? null : onValidate,
              loading: validating,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Name Page ─────────────────────────────────────────────────────────────

class _NamePage extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onNext;
  const _NamePage({required this.ctrl, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              'What should I call you?',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'I\'ll use this when talking to you.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: ctrl,
              style: GoogleFonts.inter(
                  fontSize: 16, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Your name',
                hintStyle: GoogleFonts.inter(
                    fontSize: 16, color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.border, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.amber, width: 1),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => onNext(),
            ),
            const SizedBox(height: 24),
            _PrimaryButton(label: 'Continue', onTap: onNext),
          ],
        ),
      ),
    );
  }
}

// ─── Voice Page ─────────────────────────────────────────────────────────────

class _VoicePage extends StatelessWidget {
  final bool enrolling;
  final bool done;
  final int secondsLeft;
  final double soundLevel;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  const _VoicePage({
    required this.enrolling,
    required this.done,
    required this.secondsLeft,
    required this.soundLevel,
    required this.onStart,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              done ? 'Voice captured' : 'Let me hear your voice',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              done
                  ? 'I\'ll recognize your voice from others throughout the day.'
                  : 'Speak naturally for 10 seconds — tell me about your day, read anything aloud, or just talk.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const Spacer(),
            Center(
              child: done
                  ? Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF30D158).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF30D158),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Voice registered',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: const Color(0xFF30D158),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : enrolling
                      ? Column(
                          children: [
                            WaveformWidget(
                                soundLevel: soundLevel,
                                height: 80,
                                barCount: 7),
                            const SizedBox(height: 20),
                            Text(
                              '$secondsLeft',
                              style: GoogleFonts.inter(
                                fontSize: 48,
                                fontWeight: FontWeight.w200,
                                color: AppColors.amber,
                              ),
                            ),
                            Text(
                              'seconds left',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        )
                      : Icon(
                          Icons.mic_rounded,
                          size: 80,
                          color: AppColors.textTertiary,
                        ),
            ),
            const Spacer(),
            if (done)
              _PrimaryButton(label: "Let's go", onTap: onComplete)
            else if (!enrolling)
              _PrimaryButton(label: 'Start recording', onTap: onStart)
            else
              Center(
                child: Text(
                  'Keep talking...',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (!done && !enrolling)
              Center(
                child: TextButton(
                  onPressed: onComplete,
                  child: Text(
                    'Skip this step',
                    style: GoogleFonts.inter(
                        color: AppColors.textTertiary, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
