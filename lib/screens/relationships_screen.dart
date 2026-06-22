import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/person.dart';
import '../providers/people_provider.dart';

class RelationshipsScreen extends ConsumerWidget {
  const RelationshipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(peopleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'People',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: peopleAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        data: (people) {
          if (people.isEmpty) return const _EmptyState();

          final sorted = [...people]
            ..sort((a, b) => b.mentionCount.compareTo(a.mentionCount));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) => _PersonTile(
              person: sorted[i],
              onTap: () => _showDetail(context, sorted[i], ref),
            ),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Person person, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _PersonDetailSheet(person: person, ref: ref),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final Person person;
  final VoidCallback onTap;

  const _PersonTile({required this.person, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: const Border.fromBorderSide(
                BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _relationshipColor(person.relationship).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    person.name.isNotEmpty
                        ? person.name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _relationshipColor(person.relationship),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          person.name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RelationshipBadge(
                            relationship: person.relationship),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Mentioned ${person.mentionCount}× · last ${_formatDate(person.lastMentionedAt)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    if (person.contextSnippets.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '"${person.contextSnippets.last}"',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _relationshipColor(Relationship rel) {
    switch (rel) {
      case Relationship.friend:
        return const Color(0xFF30D158);
      case Relationship.family:
        return const Color(0xFFFF9F0A);
      case Relationship.work:
        return AppColors.orbSpeaking;
      case Relationship.romantic:
        return const Color(0xFFFF375F);
      case Relationship.acquaintance:
        return AppColors.amber;
      case Relationship.unknown:
        return AppColors.textTertiary;
    }
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    if (diff < 7) return '${diff}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _RelationshipBadge extends StatelessWidget {
  final Relationship relationship;

  const _RelationshipBadge({required this.relationship});

  @override
  Widget build(BuildContext context) {
    if (relationship == Relationship.unknown) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Text(
        relationship.name,
        style: GoogleFonts.inter(
          fontSize: 10,
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PersonDetailSheet extends StatelessWidget {
  final Person person;
  final WidgetRef ref;

  const _PersonDetailSheet({required this.person, required this.ref});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, controller) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Text(
                  person.name,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                _RelationshipBadge(relationship: person.relationship),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Mentioned ${person.mentionCount} times · first met ${DateFormat('MMM d, yyyy').format(person.firstMentionedAt)}',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textTertiary),
            ),

            const SizedBox(height: 20),

            if (person.notes.isNotEmpty) ...[
              Text(
                'NOTES',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                person.notes,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
              const SizedBox(height: 20),
            ],

            if (person.contextSnippets.isNotEmpty) ...[
              Text(
                'CONTEXT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: person.contextSnippets.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: const Border.fromBorderSide(
                            BorderSide(color: AppColors.border, width: 0.5)),
                      ),
                      child: Text(
                        '"${person.contextSnippets[i]}"',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Delete button
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                ref.read(peopleProvider.notifier).deletePerson(person.id);
                Navigator.pop(context);
              },
              child: Text(
                'Remove from people',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.redAccent.withOpacity(0.8)),
              ),
            ),
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
            const Icon(Icons.people_outline_rounded,
                color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              'No people tracked yet',
              style: GoogleFonts.inter(
                  fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'As you talk about people in your life, I\'ll build a map of your relationships.',
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
