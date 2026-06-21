import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _apiKeyCtrl;
  bool _showApiKey = false;
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
    _apiKeyCtrl = TextEditingController(
      text: prefs.getString(AppConstants.prefApiKey) ?? '',
    );
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
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(AppConstants.prefUserName, _nameCtrl.text.trim());
    await prefs.setString(AppConstants.prefApiKey, _apiKeyCtrl.text.trim());
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
          _SectionLabel('Claude AI'),
          const SizedBox(height: 8),
          _SettingsTextField(
            label: 'API Key',
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
