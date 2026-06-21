import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/introspection_entry.dart';
import '../models/emotion.dart';
import '../providers/introspection_provider.dart';

class IntrospectionScreen extends ConsumerWidget {
  const IntrospectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(introspectionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Reflections',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: stateAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        data: (state) {
          if (state.entries.isEmpty) return const _EmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.entries.length,
            itemBuilder: (ctx, i) => _EntryCard(
              entry: state.entries[i],
              onAnswer: (answer) {
                ref
                    .read(introspectionProvider.notifier)
                    .recordAnswer(state.entries[i].id, answer);
              },
            ),
          );
        },
      ),
    );
  }
}

class _EntryCard extends StatefulWidget {
  final IntrospectionEntry entry;
  final ValueChanged<String> onAnswer;

  const _EntryCard({required this.entry, required this.onAnswer});

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _isEditing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.entry.answer ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hasAnswer = entry.answer != null && entry.answer!.isNotEmpty;
    final moodColor = Color(entry.mood.colorValue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: date + mood
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: moodColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.mood.emoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        entry.mood.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: moodColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, yyyy').format(entry.date),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Question
            Text(
              entry.question,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 10),

            // Answer section
            if (!_isEditing) ...[
              if (hasAnswer)
                Text(
                  entry.answer!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Text(
                  'No answer yet',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _isEditing = true),
                child: Text(
                  hasAnswer ? 'Edit answer' : 'Add answer',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.orbSpeaking,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: null,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textPrimary, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Write your reflection...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.orbSpeaking, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isEditing = false),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final answer = _ctrl.text.trim();
                      if (answer.isNotEmpty) widget.onAnswer(answer);
                      setState(() => _isEditing = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orbSpeaking,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: Text('Save',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_outlined,
                color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              'No reflections yet',
              style: GoogleFonts.inter(
                  fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'During check-ins, I\'ll occasionally ask you a deeper question to reflect on. They\'ll appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textTertiary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
