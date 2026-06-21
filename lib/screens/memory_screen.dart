import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/memory_entry.dart';
import '../providers/memory_provider.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  final _searchCtrl = TextEditingController();
  String? _searchResult;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memoryProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _searchResult = null;
    });
    try {
      final result = await ref.read(memoryProvider.notifier).searchMemories(q);
      setState(() => _searchResult = result);
    } catch (e) {
      setState(() => _searchResult = 'Error: $e');
    } finally {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Memory',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          _SearchBar(
            ctrl: _searchCtrl,
            searching: _searching,
            onSearch: _search,
          ),
          if (_searchResult != null) _SearchResult(result: _searchResult!),
          Expanded(
            child: memoriesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.amber)),
              error: (e, _) => Center(
                child: Text(e.toString(),
                    style: GoogleFonts.inter(color: AppColors.textSecondary)),
              ),
              data: (memories) => memories.isEmpty
                  ? _EmptyMemory()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: memories.length,
                      itemBuilder: (ctx, i) => _MemoryCard(
                        entry: memories[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MemoryDetailScreen(entry: memories[i]),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool searching;
  final VoidCallback onSearch;

  const _SearchBar({
    required this.ctrl,
    required this.searching,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ask about your past...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textTertiary, size: 18),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSearch,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: searching
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.black, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult extends StatelessWidget {
  final String result;
  const _SearchResult({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orbSpeaking.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.orbSpeaking.withOpacity(0.2), width: 0.5),
      ),
      child: Text(
        result,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final MemoryEntry entry;
  final VoidCallback onTap;

  const _MemoryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: const Border.fromBorderSide(
              BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _formatDate(entry.date),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amber,
                  ),
                ),
                const Spacer(),
                if (entry.userMoods.isNotEmpty)
                  Text(
                    entry.userMoods.first,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.summary,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.keyPeople.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: entry.keyPeople
                    .take(3)
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.blueDim,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          p,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.blue),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return date;
    }
  }
}

class _EmptyMemory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_outlined,
                color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              'No memories yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first nightly review to start building your memory.',
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

// ─── Memory Detail Screen ──────────────────────────────────────────────────

class MemoryDetailScreen extends ConsumerStatefulWidget {
  final MemoryEntry entry;
  const MemoryDetailScreen({super.key, required this.entry});

  @override
  ConsumerState<MemoryDetailScreen> createState() =>
      _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  late TextEditingController _summaryCtrl;
  late TextEditingController _notesCtrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _summaryCtrl = TextEditingController(text: widget.entry.summary);
    _notesCtrl = TextEditingController(text: widget.entry.rawNotes);
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    widget.entry.summary = _summaryCtrl.text;
    widget.entry.rawNotes = _notesCtrl.text;
    await ref.read(memoryProvider.notifier).updateEntry(widget.entry);
    setState(() {
      _saving = false;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _formatDate(entry.date),
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving ? 'Saving...' : 'Save',
                style: GoogleFonts.inter(color: AppColors.amber),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.textSecondary),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              label: 'Summary',
              child: _editing
                  ? TextField(
                      controller: _summaryCtrl,
                      maxLines: null,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.6),
                      decoration: _textFieldDecoration(),
                    )
                  : Text(
                      entry.summary,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.7,
                      ),
                    ),
            ),
            if (entry.keyPeople.isNotEmpty) ...[
              const SizedBox(height: 20),
              _Section(
                label: 'People',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: entry.keyPeople
                      .map((p) => _Chip(
                            text: p,
                            color: AppColors.blue,
                            bgColor: AppColors.blueDim,
                          ))
                      .toList(),
                ),
              ),
            ],
            if (entry.notableEvents.isNotEmpty) ...[
              const SizedBox(height: 20),
              _Section(
                label: 'Events',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entry.notableEvents
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(top: 7, right: 10),
                                decoration: const BoxDecoration(
                                  color: AppColors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (entry.userMoods.isNotEmpty) ...[
              const SizedBox(height: 20),
              _Section(
                label: 'Mood',
                child: Wrap(
                  spacing: 8,
                  children: entry.userMoods
                      .map((m) => _Chip(
                            text: m,
                            color: AppColors.amber,
                            bgColor: AppColors.amberDim,
                          ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _Section(
              label: 'Notes',
              child: _editing
                  ? TextField(
                      controller: _notesCtrl,
                      maxLines: null,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.6),
                      decoration: _textFieldDecoration(
                          hint: 'Add personal notes...'),
                    )
                  : entry.rawNotes.isNotEmpty
                      ? Text(
                          entry.rawNotes,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.7,
                          ),
                        )
                      : Text(
                          'No notes',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.textTertiary),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _textFieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 14),
      filled: true,
      fillColor: AppColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.amber, width: 1),
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      final months = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return date;
    }
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  final Color bgColor;

  const _Chip(
      {required this.text, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 12, color: color),
      ),
    );
  }
}
