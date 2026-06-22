import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/transcript_entry.dart';
import '../models/speaker.dart';

class TranscriptTile extends StatelessWidget {
  final TranscriptEntry entry;
  final VoidCallback? onLongPress;

  const TranscriptTile({
    super.key,
    required this.entry,
    this.onLongPress,
  });

  Color get _speakerColor {
    if (entry.isAssistant) return AppColors.orbSpeaking;
    if (entry.speakerId == SpeakerIds.user) return AppColors.amber;
    if (entry.speakerId == SpeakerIds.unknown) return AppColors.unknown;
    return AppColors.other;
  }

  @override
  Widget build(BuildContext context) {
    final isUser = entry.speakerId == SpeakerIds.user;
    final isAssistant = entry.isAssistant;
    final time = DateFormat('HH:mm').format(entry.timestamp);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isUser) ...[
              _SpeakerDot(color: _speakerColor),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isUser)
                        Text(
                          entry.speakerLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _speakerColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      if (!isUser) const SizedBox(width: 6),
                      Text(
                        time,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      if (entry.emotion != null) ...[
                        const SizedBox(width: 5),
                        Text(
                          entry.emotion!.emoji,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                      if (isUser) const SizedBox(width: 6),
                      if (isUser)
                        Text(
                          entry.speakerLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _speakerColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isAssistant
                          ? AppColors.orbSpeaking.withOpacity(0.08)
                          : isUser
                              ? AppColors.amberDim
                              : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isUser ? 12 : 4),
                        topRight: Radius.circular(isUser ? 4 : 12),
                        bottomLeft: const Radius.circular(12),
                        bottomRight: const Radius.circular(12),
                      ),
                      border: Border.all(
                        color: isAssistant
                            ? AppColors.orbSpeaking.withOpacity(0.2)
                            : isUser
                                ? AppColors.amber.withOpacity(0.3)
                                : AppColors.border,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      entry.text,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              _SpeakerDot(color: _speakerColor),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeakerDot extends StatelessWidget {
  final Color color;
  const _SpeakerDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
