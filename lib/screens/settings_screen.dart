import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/persona.dart';
import '../providers/app_providers.dart';
import '../providers/persona_provider.dart';
import '../providers/gmail_provider.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _deepseekKeyCtrl;
  late TextEditingController _elevenlabsKeyCtrl;
  late TextEditingController _elevenlabsVoiceIdCtrl;
  bool _showApiKey = false;
  bool _showDeepSeekKey = false;
  bool _showElevenLabsKey = false;
  late LlmProvider _llmProvider;
  late double _minInterval;
  late double _maxInterval;
  late bool _checkInEnabled;
  late bool _nightModeEnabled;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _nameCtrl = TextEditingController(
      text: prefs.getString(AppConstants.prefUserName) ?? '',
    );
    // API keys are loaded from secure storage into StateProviders at startup
    _apiKeyCtrl = TextEditingController(text: ref.read(apiKeyProvider));
    _deepseekKeyCtrl =
        TextEditingController(text: ref.read(deepseekApiKeyProvider));
    _elevenlabsKeyCtrl =
        TextEditingController(text: ref.read(elevenlabsApiKeyProvider));
    _elevenlabsVoiceIdCtrl =
        TextEditingController(text: ref.read(elevenlabsVoiceIdProvider));
    final providerStr = prefs.getString(AppConstants.prefLlmProvider) ?? 'claude';
    _llmProvider = providerStr == 'deepseek' ? LlmProvider.deepseek : LlmProvider.claude;
    _minInterval = (prefs.getInt(AppConstants.prefCheckInMinInterval) ??
            AppConstants.minCheckInMinutes)
        .toDouble();
    _maxInterval = (prefs.getInt(AppConstants.prefCheckInMaxInterval) ??
            AppConstants.maxCheckInMinutes)
        .toDouble();
    _checkInEnabled = prefs.getBool(AppConstants.prefCheckInEnabled) ?? true;
    _nightModeEnabled =
        prefs.getBool(AppConstants.prefNightModeEnabled) ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apiKeyCtrl.dispose();
    _deepseekKeyCtrl.dispose();
    _elevenlabsKeyCtrl.dispose();
    _elevenlabsVoiceIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final secure = ref.read(secureStorageProvider);

    // API keys → encrypted secure storage
    final claudeKey = _apiKeyCtrl.text.trim();
    final deepseekKey = _deepseekKeyCtrl.text.trim();
    final elKey = _elevenlabsKeyCtrl.text.trim();
    final elVoiceId = _elevenlabsVoiceIdCtrl.text.trim();
    await Future.wait([
      secure.write(key: AppConstants.prefApiKey, value: claudeKey),
      secure.write(key: AppConstants.prefDeepSeekApiKey, value: deepseekKey),
      secure.write(key: AppConstants.prefElevenLabsApiKey, value: elKey),
      secure.write(key: AppConstants.prefElevenLabsVoiceId, value: elVoiceId),
    ]);
    // Update in-memory providers so services rebuild immediately
    ref.read(apiKeyProvider.notifier).state = claudeKey;
    ref.read(deepseekApiKeyProvider.notifier).state = deepseekKey;
    ref.read(elevenlabsApiKeyProvider.notifier).state = elKey;
    ref.read(elevenlabsVoiceIdProvider.notifier).state = elVoiceId;

    // Non-sensitive settings stay in SharedPreferences
    await prefs.setString(AppConstants.prefUserName, _nameCtrl.text.trim());
    await prefs.setString(AppConstants.prefLlmProvider,
        _llmProvider == LlmProvider.deepseek ? 'deepseek' : 'claude');
    await prefs.setInt(
        AppConstants.prefCheckInMinInterval, _minInterval.round());
    await prefs.setInt(
        AppConstants.prefCheckInMaxInterval, _maxInterval.round());
    await prefs.setBool(AppConstants.prefCheckInEnabled, _checkInEnabled);
    await prefs.setBool(AppConstants.prefNightModeEnabled, _nightModeEnabled);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Settings saved',
            style: GoogleFonts.inter(color: Colors.black)),
        backgroundColor: AppColors.amber,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Clear all data?',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'This will delete all transcripts and memories. This cannot be undone.',
          style:
              GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.inter(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(storageServiceProvider).clearAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All data cleared',
              style: GoogleFonts.inter(color: Colors.black)),
          backgroundColor: AppColors.amber,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: AppColors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SectionLabel('Profile'),
          const SizedBox(height: 8),
          _SettingsTextField(
            label: 'Your name',
            ctrl: _nameCtrl,
          ),
          const SizedBox(height: 24),
          _SectionLabel('AI Model'),
          const SizedBox(height: 8),
          _ModelSelector(
            selected: _llmProvider,
            onChanged: (v) => setState(() => _llmProvider = v),
          ),
          const SizedBox(height: 12),
          _SettingsTextField(
            label: 'Claude API Key',
            ctrl: _apiKeyCtrl,
            obscure: !_showApiKey,
            suffix: IconButton(
              icon: Icon(
                _showApiKey ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textTertiary,
                size: 18,
              ),
              onPressed: () => setState(() => _showApiKey = !_showApiKey),
            ),
          ),
          if (_llmProvider == LlmProvider.deepseek) ...[
            const SizedBox(height: 10),
            _SettingsTextField(
              label: 'DeepSeek API Key',
              ctrl: _deepseekKeyCtrl,
              obscure: !_showDeepSeekKey,
              suffix: IconButton(
                icon: Icon(
                  _showDeepSeekKey ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
                onPressed: () => setState(() => _showDeepSeekKey = !_showDeepSeekKey),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionLabel('Voice'),
          const SizedBox(height: 8),
          _SettingsTextField(
            label: 'ElevenLabs API Key',
            ctrl: _elevenlabsKeyCtrl,
            obscure: !_showElevenLabsKey,
            suffix: IconButton(
              icon: Icon(
                _showElevenLabsKey ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textTertiary,
                size: 18,
              ),
              onPressed: () => setState(() => _showElevenLabsKey = !_showElevenLabsKey),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsTextField(
            label: 'Voice ID',
            ctrl: _elevenlabsVoiceIdCtrl,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              'Find Voice IDs at elevenlabs.io/voice-lab. Leave blank to use device voice.',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary, height: 1.4),
            ),
          ),
          const SizedBox(height: 10),
          _TestVoiceButton(),
          const SizedBox(height: 24),
          _SectionLabel('Check-ins'),
          const SizedBox(height: 8),
          _SettingsTile(
            title: 'Proactive check-ins',
            subtitle: 'I\'ll check in on you throughout the day',
            trailing: Switch(
              value: _checkInEnabled,
              onChanged: (v) => setState(() => _checkInEnabled = v),
            ),
          ),
          if (_checkInEnabled) ...[
            const SizedBox(height: 16),
            _SliderTile(
              label:
                  'Min interval: ${_minInterval.round()} min',
              value: _minInterval,
              min: 3,
              max: 20,
              onChanged: (v) {
                if (v < _maxInterval) setState(() => _minInterval = v);
              },
            ),
            const SizedBox(height: 8),
            _SliderTile(
              label:
                  'Max interval: ${_maxInterval.round()} min',
              value: _maxInterval,
              min: 10,
              max: 60,
              onChanged: (v) {
                if (v > _minInterval) setState(() => _maxInterval = v);
              },
            ),
          ],
          const SizedBox(height: 24),
          _SectionLabel('Night Mode'),
          const SizedBox(height: 8),
          _SettingsTile(
            title: 'Quiet hours',
            subtitle:
                'No check-ins between 11pm – 7am',
            trailing: Switch(
              value: _nightModeEnabled,
              onChanged: (v) => setState(() => _nightModeEnabled = v),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Persona'),
          const SizedBox(height: 8),
          _PersonaSelector(),
          const SizedBox(height: 24),
          _SectionLabel('Connected Accounts'),
          const SizedBox(height: 8),
          _ConnectedAccountsTile(),
          const SizedBox(height: 32),
          _SectionLabel('Data'),
          const SizedBox(height: 8),
          _DangerTile(
            label: 'Re-enroll voice',
            onTap: () => Navigator.pushNamed(context, '/onboarding'),
          ),
          const SizedBox(height: 8),
          _DangerTile(
            label: 'Clear all data',
            onTap: _clearAllData,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool obscure;
  final Widget? suffix;

  const _SettingsTextField({
    required this.label,
    required this.ctrl,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceElevated,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.amber, width: 1),
            ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textPrimary),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DangerTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DangerTile({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.redAccent.withOpacity(0.07)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.fromBorderSide(
            BorderSide(
              color: isDestructive
                  ? Colors.redAccent.withOpacity(0.2)
                  : AppColors.border,
              width: 0.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDestructive ? Colors.redAccent : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─── Model Selector ───────────────────────────────────────────────────────

class _ModelSelector extends StatelessWidget {
  final LlmProvider selected;
  final ValueChanged<LlmProvider> onChanged;
  const _ModelSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: LlmProvider.values.map((p) {
        final isSelected = p == selected;
        final label = p == LlmProvider.claude ? 'Claude' : 'DeepSeek';
        final sub = p == LlmProvider.claude ? 'Anthropic' : 'Cheaper · OpenAI-compat';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: p == LlmProvider.claude ? 8 : 0),
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.amber.withOpacity(0.08)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.fromBorderSide(BorderSide(
                    color: isSelected
                        ? AppColors.amber.withOpacity(0.5)
                        : AppColors.border,
                    width: isSelected ? 1 : 0.5,
                  )),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.amber : AppColors.textPrimary,
                          ),
                        ),
                        if (isSelected) ...[
                          const Spacer(),
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.amber, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textTertiary)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Test Voice Button ────────────────────────────────────────────────────

class _TestVoiceButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TestVoiceButton> createState() => _TestVoiceButtonState();
}

class _TestVoiceButtonState extends ConsumerState<_TestVoiceButton> {
  bool _testing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _testing ? null : _test,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(
              BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _testing ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
              size: 16,
              color: _testing ? AppColors.orbSpeaking : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              _testing ? 'Speaking…' : 'Test voice',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _testing ? AppColors.orbSpeaking : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await ref
          .read(ttsServiceProvider)
          .speak("Hey, your soul is listening. This is how I sound.");
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }
}

class _ConnectedAccountsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gmailAsync = ref.watch(gmailProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500),
                ),
                gmailAsync.when(
                  loading: () => Text('Connecting…',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary)),
                  error: (_, __) => Text('Not connected',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  data: (account) => Text(
                    account != null ? account.email : 'Calendar + Gmail for morning briefing',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: account != null ? AppColors.textSecondary : AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          gmailAsync.when(
            loading: () => const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber)),
            error: (_, __) => _connectButton(ref),
            data: (account) => account != null
                ? TextButton(
                    onPressed: () => ref.read(gmailProvider.notifier).signOut(),
                    child: Text('Disconnect',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary)),
                  )
                : _connectButton(ref),
          ),
        ],
      ),
    );
  }

  Widget _connectButton(WidgetRef ref) {
    return TextButton(
      onPressed: () => ref.read(gmailProvider.notifier).signIn(),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.amber.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Text('Connect',
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.amber, fontWeight: FontWeight.w600)),
    );
  }
}

class _PersonaSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(personaProvider);

    return Column(
      children: Persona.values.map((p) {
        final selected = p == current;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => ref.read(personaProvider.notifier).setPersona(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.amber.withOpacity(0.08)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.fromBorderSide(
                  BorderSide(
                    color: selected
                        ? AppColors.amber.withOpacity(0.5)
                        : AppColors.border,
                    width: selected ? 1 : 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(p.icon,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? AppColors.amber
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          p.description,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.amber, size: 18),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
