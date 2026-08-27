import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/models/combo.dart';
import '../../core/models/trick_submission.dart';
import '../../theme/app_colors.dart';
import '../../widgets/difficulty_chip.dart';

class AdminSubmissionsScreen extends StatefulWidget {
  const AdminSubmissionsScreen({super.key});

  @override
  State<AdminSubmissionsScreen> createState() => _AdminSubmissionsScreenState();
}

class _AdminSubmissionsScreenState extends State<AdminSubmissionsScreen> {
  late Future<List<TrickSubmissionDto>> _future;
  late Future<List<ComboDto>> _comboFuture;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ApiClient.instance.getPendingSubmissions();
      _comboFuture = ApiClient.instance.getPendingComboReviews();
    });
  }

  Future<void> _act(String id, Future<void> Function() action) async {
    setState(() => _processing.add(id));
    try {
      await action();
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      setState(() => _processing.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        titleSpacing: 22,
        title: const Text('Approvals'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: _CircleIconButton(icon: Icons.refresh, onTap: _load),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.indigo,
        onRefresh: () async => _load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader('Combo publication requests'),
              const SizedBox(height: 12),
              FutureBuilder<List<ComboDto>>(
                future: _comboFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator(color: AppColors.indigo)),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.red)),
                    );
                  }
                  final combos = snapshot.data ?? [];
                  if (combos.isEmpty) {
                    return _EmptyNote('No combos pending review.');
                  }
                  return Column(
                    children: combos.map((combo) {
                      final busy = _processing.contains(combo.id);
                      return _ComboReviewCard(
                        combo: combo,
                        busy: busy,
                        onApprove: () => _act(combo.id, () => ApiClient.instance.approveComboVisibility(combo.id)),
                        onReject: () => _act(combo.id, () => ApiClient.instance.rejectComboVisibility(combo.id)),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 22),
              _SectionHeader('Trick submissions'),
              const SizedBox(height: 12),
              FutureBuilder<List<TrickSubmissionDto>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator(color: AppColors.indigo)),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.red)),
                    );
                  }
                  final submissions = snapshot.data ?? [];
                  if (submissions.isEmpty) {
                    return _EmptyNote('No pending submissions.');
                  }
                  return Column(
                    children: submissions.map((s) {
                      final busy = _processing.contains(s.id);
                      return _TrickSubmissionCard(
                        submission: s,
                        busy: busy,
                        onApprove: () => _act(s.id, () => ApiClient.instance.approveSubmission(s.id)),
                        onReject: () => _act(s.id, () => ApiClient.instance.rejectSubmission(s.id)),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.faint),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: GoogleFonts.plusJakartaSans(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 13.5)),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6), spreadRadius: -16),
        ],
      ),
      child: child,
    );
  }
}

class _ApproveRejectRow extends StatelessWidget {
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _ApproveRejectRow({required this.busy, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              onPressed: busy ? null : onApprove,
              child: busy
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Approve', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 42,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              onPressed: busy ? null : onReject,
              child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComboReviewCard extends StatelessWidget {
  final ComboDto combo;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ComboReviewCard({required this.combo, required this.busy, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (combo.name != null && combo.name!.isNotEmpty) ? combo.name! : combo.displayText,
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'by ${combo.ownerUserName ?? '?'} · ${combo.trickCount} tricks',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DifficultyChip(combo.totalDifficulty.toInt()),
            ],
          ),
          if (combo.tricks != null && combo.tricks!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: combo.tricks!.map((t) {
                final label = t.type == 'combo' ? (t.subComboName ?? 'Combo') : (t.abbreviation ?? '?');
                final suffix = t.noTouch ? '·nt' : (!t.strongFoot ? '·wf' : '');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: t.noTouch ? AppColors.noTouchBg : AppColors.chipBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${t.position}. $label$suffix',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.noTouch ? AppColors.noTouchText : AppColors.ink2,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          _ApproveRejectRow(busy: busy, onApprove: onApprove, onReject: onReject),
        ],
      ),
    );
  }
}

class _TrickSubmissionCard extends StatelessWidget {
  final TrickSubmissionDto submission;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _TrickSubmissionCard({required this.submission, required this.busy, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.name,
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(7)),
                child: Text(
                  'PENDING',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: AppColors.amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${s.abbreviation} · by ${s.submittedByUserName} · ${s.submittedAt.toLocal().toString().substring(0, 10)}',
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Stat('Revs', s.revolution.toString()),
              _Stat('Difficulty', '${s.difficulty}'),
              _Stat('Common lvl', '${s.commonLevel}'),
              _Stat('Cross-over', s.crossOver ? 'Yes' : 'No'),
              _Stat('Knee', s.knee ? 'Yes' : 'No'),
            ],
          ),
          const SizedBox(height: 14),
          _ApproveRejectRow(busy: busy, onApprove: onApprove, onReject: onReject),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: AppColors.faint)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: const BorderSide(color: AppColors.line2)),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 20, color: AppColors.ink2)),
      ),
    );
  }
}
