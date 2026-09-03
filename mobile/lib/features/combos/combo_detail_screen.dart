import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';
import '../../theme/app_colors.dart';
import '../../widgets/combo_card.dart' show TrickNameDisplay;
import '../../widgets/confirm_sheet.dart';
import '../../widgets/difficulty_chip.dart';
import '../../widgets/foot_toggle.dart';
import '../../widgets/rate_combo_dialog.dart';
import '../../widgets/setting_icon_button.dart';

class _SlotItem {
  final String? trickId;
  final String trickName;
  final String abbreviation;
  bool crossOver;
  int position;
  bool strongFoot;
  bool noTouch;
  final bool isTransition;

  // Sub-combo support
  final bool isSubCombo;
  final String? subComboId;
  final String? subComboName;
  final List<ComboTrickDto>? subComboTricks;

  _SlotItem({
    this.trickId,
    required this.trickName,
    required this.abbreviation,
    required this.crossOver,
    required this.position,
    this.strongFoot = true,
    this.noTouch = false,
    this.isTransition = false,
    this.isSubCombo = false,
    this.subComboId,
    this.subComboName,
    this.subComboTricks,
  });
}

class ComboDetailScreen extends StatefulWidget {
  final String id;
  const ComboDetailScreen({super.key, required this.id});

  @override
  State<ComboDetailScreen> createState() => _ComboDetailScreenState();
}

class _ComboDetailScreenState extends State<ComboDetailScreen> {
  late Future<ComboDto> _future;
  final _shareButtonKey = GlobalKey();

  bool _favLoading = false;
  bool _favoured = false;
  bool _completedLoading = false;
  bool _completed = false;
  bool _personalReusableLoading = false;
  bool _isPersonalReusable = false;

  Future<void> _deleteCombo(String comboId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete combo?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.instance.deleteCombo(comboId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ApiClient.instance.getComboById(widget.id);
    });
    _future.then((combo) {
      if (mounted) {
        setState(() {
          _favoured = combo.isFavourited;
          _completed = combo.isCompleted;
          _isPersonalReusable = combo.isPersonalReusable;
        });
      }
    });
  }

  Future<void> _openEdit(ComboDto combo) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditComboScreen(combo: combo),
        fullscreenDialog: true,
      ),
    );
    if (updated == true) _load();
  }

  void _openRating(String comboId) {
    showDialog<void>(
      context: context,
      builder: (_) => RateComboDialog(
        comboId: comboId,
        onRated: _load,
      ),
    );
  }

  Future<void> _toggleFavourite(String comboId) async {
    setState(() => _favLoading = true);
    try {
      if (_favoured) {
        await ApiClient.instance.removeFavourite(comboId);
      } else {
        await ApiClient.instance.addFavourite(comboId);
      }
      setState(() => _favoured = !_favoured);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Future<void> _togglePersonalReusable(String comboId) async {
    final confirmed = await showConfirmSheet(
      context,
      title: _isPersonalReusable ? 'Remove from your trick list?' : 'List combo in your trick list?',
      description: _isPersonalReusable
          ? 'This combo will no longer show up when you\'re building other combos.'
          : 'This combo will show up as a selectable item — alongside tricks — when you\'re building other combos. Only you will see it there.',
      confirmLabel: _isPersonalReusable ? 'Remove' : 'List it',
    );
    if (!confirmed) return;

    setState(() => _personalReusableLoading = true);
    try {
      if (_isPersonalReusable) {
        await ApiClient.instance.removePersonalReusable(comboId);
      } else {
        await ApiClient.instance.addPersonalReusable(comboId);
      }
      setState(() => _isPersonalReusable = !_isPersonalReusable);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _personalReusableLoading = false);
    }
  }

  Future<void> _shareCombo(ComboDto combo) async {
    final url = '$kWebOrigin/share/combos/${combo.id}';
    // iOS requires a non-zero sharePositionOrigin (the share sheet's popover
    // anchor) — without it the native call throws PlatformException instead
    // of presenting anything, even on iPhone.
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? (box.localToGlobal(Offset.zero) & box.size)
        : const Rect.fromLTWH(0, 0, 1, 1); // just needs to be non-zero; only affects iPad popover arrow position
    await Share.share(url, subject: combo.name ?? combo.displayText, sharePositionOrigin: origin);
  }

  void _saveCopy(ComboDto combo) {
    if (!AuthService.instance.isAuthenticated) {
      context.push('/login');
      return;
    }
    context.push('/combos/create', extra: CopyFromCombo(tricks: combo.tricks ?? [], name: combo.name));
  }

  Future<void> _toggleCompleted(String comboId) async {
    setState(() => _completedLoading = true);
    try {
      if (_completed) {
        await ApiClient.instance.unmarkCompleted(comboId);
      } else {
        await ApiClient.instance.markCompleted(comboId);
      }
      setState(() => _completed = !_completed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _completedLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<ComboDto>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.indigo));
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          final combo = snap.data!;
          final currentUserId = AuthService.instance.userId;
          final isOwner = combo.ownerId == currentUserId;
          final isAdmin = AuthService.instance.isAdmin;
          final authed = currentUserId != null;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _DetailHero(
                  combo: combo,
                  isOwner: isOwner,
                  isAdmin: isAdmin,
                  authed: authed,
                  favoured: _favoured,
                  favLoading: _favLoading,
                  onToggleFavourite: () => _toggleFavourite(combo.id),
                  isPersonalReusable: _isPersonalReusable,
                  personalReusableLoading: _personalReusableLoading,
                  onTogglePersonalReusable: () => _togglePersonalReusable(combo.id),
                  onEdit: () => _openEdit(combo),
                  onDelete: () => _deleteCombo(combo.id),
                  onShare: () => _shareCombo(combo),
                  onSaveCopy: isOwner ? null : () => _saveCopy(combo),
                  shareButtonKey: _shareButtonKey,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (combo.aiDescription != null && combo.aiDescription!.isNotEmpty)
                      _AiDescriptionCard(text: combo.aiDescription!),
                    if (combo.tricks != null && combo.tricks!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SEQUENCE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppColors.faint,
                            ),
                          ),
                          Row(
                            children: [
                              _nameFormatChip('Full name', TrickNameDisplay.showFullName),
                              const SizedBox(width: 6),
                              _nameFormatChip('Abbr.', !TrickNameDisplay.showFullName),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < combo.tricks!.length; i++)
                        _SequenceStep(
                          trick: combo.tricks![i],
                          isLast: i == combo.tricks!.length - 1,
                        ),
                    ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<ComboDto>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          final combo = snap.data!;
          final currentUserId = AuthService.instance.userId;
          final isOwner = combo.ownerId == currentUserId;
          final authed = currentUserId != null;
          final canRate = !isOwner && authed;
          if (!authed) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (canRate) ...[
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => _openRating(combo.id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.star,
                            side: const BorderSide(color: Color(0xFFFDE68A)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.star_rounded),
                          label: const Text('Rate', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                  ],
                  Expanded(
                    flex: canRate ? 2 : 1,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _completedLoading ? null : () => _toggleCompleted(combo.id),
                        style: FilledButton.styleFrom(
                          backgroundColor: _completed ? AppColors.green : AppColors.indigo,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Icon(_completed ? Icons.check_circle : Icons.check_circle_outline),
                        label: Text(
                          _completed ? 'Marked as done' : 'Mark as done',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _nameFormatChip(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => TrickNameDisplay.showFullName = label == 'Full name'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.indigo : AppColors.chipBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

/// Formats the trick list as "(ABBR)(nt) (ABBR) (SubCombo)…" for the hero
/// headline — each trick wrapped in parentheses, with "(nt)" appended right
/// after any no-touch trick. Returns null when there's nothing to format
/// (caller falls back to combo.displayText).
String? _formatSequence(List<ComboTrickDto>? tricks) {
  if (tricks == null || tricks.isEmpty) return null;
  final buffer = StringBuffer();
  for (final t in tricks) {
    final label = t.type == 'combo'
        ? (t.subComboName ?? 'Combo')
        : TrickNameDisplay.label(isTransition: t.isTransition, name: t.name, abbreviation: t.abbreviation);
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write('($label)');
    if (t.noTouch && !t.isTransition) buffer.write('(nt)');
  }
  return buffer.toString();
}

class _DetailHero extends StatelessWidget {
  final ComboDto combo;
  final bool isOwner;
  final bool isAdmin;
  final bool authed;
  final bool favoured;
  final bool favLoading;
  final VoidCallback onToggleFavourite;
  final bool isPersonalReusable;
  final bool personalReusableLoading;
  final VoidCallback onTogglePersonalReusable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback? onSaveCopy;
  final Key shareButtonKey;

  const _DetailHero({
    required this.combo,
    required this.isOwner,
    required this.isAdmin,
    required this.authed,
    required this.favoured,
    required this.favLoading,
    required this.onToggleFavourite,
    required this.isPersonalReusable,
    required this.personalReusableLoading,
    required this.onTogglePersonalReusable,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onSaveCopy,
    required this.shareButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.grad),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lime.withValues(alpha: 0.18),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _HeroIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          // Reached here via go() + pushReplacement (e.g. Generate ->
                          // save -> "View combo"), which can leave nothing to pop to.
                          onTap: () => context.canPop() ? context.pop() : context.go('/combos'),
                        ),
                        const Spacer(),
                        if (authed)
                          _HeroIconButton(
                            icon: favoured ? Icons.favorite : Icons.favorite_border,
                            iconColor: favoured ? AppColors.pink : Colors.white,
                            onTap: favLoading ? null : onToggleFavourite,
                          ),
                        if (authed && (isOwner || combo.visibility == 'Public' || isAdmin)) ...[
                          const SizedBox(width: 9),
                          _HeroIconButton(
                            icon: isPersonalReusable ? Icons.link : Icons.link_off,
                            iconColor: isPersonalReusable ? AppColors.lime : Colors.white,
                            onTap: personalReusableLoading ? null : onTogglePersonalReusable,
                          ),
                        ],
                        if (isOwner || combo.visibility == 'Public') ...[
                          const SizedBox(width: 9),
                          _HeroIconButton(key: shareButtonKey, icon: Icons.ios_share, onTap: onShare),
                        ],
                        if (!isOwner && onSaveCopy != null) ...[
                          const SizedBox(width: 9),
                          _HeroIconButton(icon: Icons.playlist_add, onTap: onSaveCopy),
                        ],
                        if (isOwner) ...[
                          const SizedBox(width: 9),
                          _HeroIconButton(icon: Icons.edit_outlined, onTap: onEdit),
                        ],
                        if (isOwner || isAdmin) ...[
                          const SizedBox(width: 9),
                          _HeroIconButton(icon: Icons.delete_outline, onTap: onDelete),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Combo${combo.ownerUserName != null ? ' · by ${combo.ownerUserName}' : ''}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (combo.name != null && combo.name!.isNotEmpty)
                          ? combo.name!
                          : _formatSequence(combo.tricks) ?? combo.displayText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StatPill(value: '${combo.totalDifficulty.toInt()}', label: 'Difficulty'),
                        const SizedBox(width: 9),
                        _StatPill(value: '${combo.trickCount}', label: 'Tricks'),
                        const SizedBox(width: 9),
                        _StatPill(
                          value: combo.totalRatings > 0
                              ? '${combo.averageRating.toStringAsFixed(1)}★'
                              : '—',
                          label: combo.totalRatings > 0 ? '${combo.totalRatings} ratings' : 'No ratings',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _HeroIconButton({super.key, required this.icon, this.iconColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 19, color: iconColor ?? Colors.white),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  const _StatPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiDescriptionCard extends StatelessWidget {
  final String text;
  const _AiDescriptionCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1FE),
        border: Border.all(color: const Color(0xFFE5E0FB)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$text"',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF4B3FA8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF8B7CE0)),
              const SizedBox(width: 6),
              Text(
                'GENERATED BY CLAUDE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: const Color(0xFF8B7CE0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SequenceStep extends StatefulWidget {
  final ComboTrickDto trick;
  final bool isLast;
  const _SequenceStep({required this.trick, required this.isLast});

  @override
  State<_SequenceStep> createState() => _SequenceStepState();
}

class _SequenceStepState extends State<_SequenceStep> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trick;
    final isSubCombo = t.type == 'combo';
    final highlight = t.noTouch;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: highlight ? AppColors.indigo : AppColors.surface,
                  border: Border.all(color: AppColors.indigo, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${t.position}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: highlight ? Colors.white : AppColors.indigo,
                  ),
                ),
              ),
              if (!widget.isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.line2, margin: const EdgeInsets.symmetric(vertical: 4)),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: isSubCombo ? _buildSubCombo(t) : _buildTrick(t),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrick(ComboTrickDto t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              TrickNameDisplay.label(isTransition: t.isTransition, name: t.name, abbreviation: t.abbreviation),
              style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!t.isTransition) ...[
            FootToggle(value: t.strongFoot),
            const SizedBox(width: 6),
          ],
          if (t.noTouch && !t.isTransition) ...[
            _FlagTag(label: 'NT', bg: AppColors.noTouchBg, fg: AppColors.noTouchText),
            const SizedBox(width: 6),
          ],
          if (t.difficulty > 0) DifficultyChip(t.difficulty),
        ],
      ),
    );
  }

  Widget _buildSubCombo(ComboTrickDto t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.noTouchBg,
              border: Border.all(color: const Color(0xFFE5E0FB)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'COMBO',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.noTouchText,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.subComboName ?? 'Sub-combo',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${t.subComboTricks?.length ?? 0} tricks',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AppColors.noTouchText,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (t.subComboTricks ?? []).map((st) {
                final label = st.abbreviation ?? '?';
                final suffix = st.isTransition ? '' : (st.noTouch ? '·nt' : (!st.strongFoot ? '·wf' : ''));
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${st.position}. $label$suffix',
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink2),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _FlagTag extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _FlagTag({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

// ── Edit Combo Screen ──────────────────────────────────────────────────────────

class _EditComboScreen extends StatefulWidget {
  final ComboDto combo;
  const _EditComboScreen({required this.combo});

  @override
  State<_EditComboScreen> createState() => _EditComboScreenState();
}

class _EditComboScreenState extends State<_EditComboScreen> {
  late final TextEditingController _nameCtrl;
  late final List<_SlotItem> _slots;
  List<TrickListItem> _items = [];
  bool _loadingTricks = true;
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _saving = false;
  String? _error;
  int _tab = 0;
  late bool _isPublic = widget.combo.visibility != 'Private';
  late bool _isPersonalReusable = widget.combo.isPersonalReusable;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.combo.name ?? '');
    _slots = (widget.combo.tricks ?? []).map((t) {
      if (t.type == 'combo') {
        return _SlotItem(
          trickId: t.trickId,
          trickName: t.subComboName ?? '',
          abbreviation: '',
          crossOver: false,
          position: t.position,
          strongFoot: t.strongFoot,
          noTouch: t.noTouch,
          isSubCombo: true,
          subComboId: t.subComboId,
          subComboName: t.subComboName,
          subComboTricks: t.subComboTricks,
        );
      }
      return _SlotItem(
        trickId: t.trickId,
        trickName: t.name ?? '',
        abbreviation: t.abbreviation ?? '',
        crossOver: false, // will be updated when tricks load
        position: t.position,
        // A transition trick (e.g. "Combo") has no foot/no-touch of its own —
        // normalize away any stale flags from before this was enforced.
        strongFoot: t.isTransition ? true : t.strongFoot,
        noTouch: t.isTransition ? false : t.noTouch,
        isTransition: t.isTransition,
      );
    }).toList();
    _loadTricks();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTricks() async {
    try {
      final items = await ApiClient.instance.getTricks();
      if (mounted) {
        final trickMap = {for (final t in items.whereType<TrickItem>()) t.id: t};
        for (final slot in _slots) {
          if (!slot.isSubCombo) {
            final trick = trickMap[slot.trickId];
            if (trick != null) slot.crossOver = trick.crossOver;
          }
        }
        setState(() => _items = items);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingTricks = false);
    }
  }

  List<TrickListItem> get _filtered {
    final q = _search.toLowerCase();
    if (q.isEmpty) return _items;
    final list = _items.where((item) {
      if (item is TrickItem) {
        return item.name.toLowerCase().contains(q) || item.abbreviation.toLowerCase().contains(q);
      } else if (item is ComboItem) {
        return item.displayName.toLowerCase().contains(q);
      }
      return false;
    }).toList();

    bool isExact(TrickListItem item) {
      if (item is TrickItem) return item.abbreviation.toLowerCase() == q || item.name.toLowerCase() == q;
      if (item is ComboItem) return item.displayName.toLowerCase() == q;
      return false;
    }

    return [...list.where(isExact), ...list.where((item) => !isExact(item))];
  }

  void _addTrick(TrickItem trick) {
    setState(() {
      _slots.add(_SlotItem(
        trickId: trick.id,
        trickName: trick.name,
        abbreviation: trick.abbreviation,
        crossOver: trick.crossOver,
        position: _slots.length + 1,
        isTransition: trick.isTransition,
      ));
      _tab = 1;
    });
  }

  void _addCombo(ComboItem combo) {
    setState(() {
      _slots.add(_SlotItem(
        trickId: '',
        trickName: combo.displayName,
        abbreviation: '',
        crossOver: false,
        position: _slots.length + 1,
        isSubCombo: true,
        subComboId: combo.id,
        subComboName: combo.displayName,
        subComboTricks: combo.tricks,
      ));
      _tab = 1;
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index);
      for (var i = 0; i < _slots.length; i++) _slots[i].position = i + 1;
    });
  }

  Future<void> _save() async {
    if (_slots.isEmpty) return;
    setState(() { _saving = true; _error = null; });
    try {
      final name = _nameCtrl.text.trim();
      final tricks = _slots.map((s) {
        if (s.isSubCombo) {
          return BuildComboTrickItem(
            subComboId: s.subComboId,
            position: s.position,
            strongFoot: s.strongFoot,
            noTouch: s.noTouch,
          );
        }
        return BuildComboTrickItem(
          trickId: s.trickId,
          position: s.position,
          strongFoot: s.strongFoot,
          noTouch: s.noTouch,
        );
      }).toList();
      await ApiClient.instance.updateCombo(
        widget.combo.id,
        name: name,
        tricks: tricks,
      );
      if (widget.combo.visibility == 'Private' && _isPublic) {
        await ApiClient.instance.setVisibility(widget.combo.id, true);
      }
      if (_isPersonalReusable != widget.combo.isPersonalReusable) {
        if (_isPersonalReusable) {
          await ApiClient.instance.addPersonalReusable(widget.combo.id);
        } else {
          await ApiClient.instance.removePersonalReusable(widget.combo.id);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Edit combo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton(
              onPressed: _saving || _slots.isEmpty ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.indigo))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.indigo)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: TextField(
              controller: _nameCtrl,
              style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Combo name (optional)',
                filled: true,
                fillColor: AppColors.chipBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.combo.visibility == 'Private')
                SettingIconButton(
                  activeIcon: Icons.public,
                  inactiveIcon: Icons.public_off,
                  active: _isPublic,
                  activeColor: AppColors.indigo,
                  title: _isPublic ? 'Stop submitting as public?' : 'Submit as public?',
                  description: _isPublic
                      ? "This combo will be saved as private instead — it won't be sent for admin review or shown to other users."
                      : 'An admin will review this combo before it becomes visible to everyone. Until approved, only you can see it.',
                  confirmLabel: _isPublic ? 'Keep it private' : 'Submit for review',
                  onChanged: (v) => setState(() => _isPublic = v),
                ),
              if (widget.combo.visibility == 'Private') const SizedBox(width: 12),
              SettingIconButton(
                activeIcon: Icons.link,
                inactiveIcon: Icons.link_off,
                active: _isPersonalReusable,
                activeColor: AppColors.violet,
                title: _isPersonalReusable ? 'Remove from your trick list?' : 'List combo in your trick list?',
                description: _isPersonalReusable
                    ? "This combo will no longer show up when you're building other combos."
                    : "This combo will show up as a selectable item — alongside tricks — when you're building other combos. Only you will see it there.",
                confirmLabel: _isPersonalReusable ? 'Remove' : 'List it',
                onChanged: (v) => setState(() => _isPersonalReusable = v),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _EditSegmented(
              labels: ['Tricks (${_items.length})', 'Combo (${_slots.length})'],
              selectedIndex: _tab,
              onSelected: (i) => setState(() => _tab = i),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [_pickerTab(), _comboTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: TextField(
            controller: _searchCtrl,
            autocorrect: false,
            enableSuggestions: false,
            style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'Search…',
              hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.faint, fontWeight: FontWeight.w600),
              prefixIcon: const Icon(Icons.search, color: AppColors.faint),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, color: AppColors.faint), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                  : null,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loadingTricks
              ? const Center(child: CircularProgressIndicator(color: AppColors.indigo))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final item = _filtered[i];
                    if (item is TrickItem) {
                      return _EditPickerRow(
                        abbreviation: item.abbreviation,
                        name: item.name,
                        meta: '${item.crossOver ? 'crossover' : ''}${item.crossOver && item.knee ? ' · ' : ''}${item.knee ? 'knee' : ''}',
                        difficulty: item.difficulty,
                        isCombo: false,
                        onTap: () => _addTrick(item),
                      );
                    } else if (item is ComboItem) {
                      return _EditPickerRow(
                        abbreviation: null,
                        name: item.displayName,
                        meta: '${item.trickCount} tricks',
                        difficulty: item.totalDifficulty.toInt(),
                        isCombo: true,
                        onTap: () => _addCombo(item),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
        ),
      ],
    );
  }

  Widget _comboTab() {
    if (_slots.isEmpty) {
      return Center(
        child: Text(
          'Add tricks from the Tricks tab.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      itemCount: _slots.length,
      itemBuilder: (_, i) {
        final s = _slots[i];
        if (s.isSubCombo) {
          return _EditSubComboSlot(slot: s, onRemove: () => _removeSlot(i));
        }
        return _EditSlot(
          slot: s,
          onRemove: () => _removeSlot(i),
          onToggleStrongFoot: (v) => setState(() => s.strongFoot = v),
          onToggleNoTouch: (v) => setState(() => s.noTouch = v),
        );
      },
    );
  }
}

class _EditSegmented extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _EditSegmented({required this.labels, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE7E6F0), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == selectedIndex
                        ? [BoxShadow(color: AppColors.ink.withValues(alpha: 0.12), blurRadius: 3, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: i == selectedIndex ? AppColors.ink : AppColors.muted,
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

class _EditPickerRow extends StatelessWidget {
  final String? abbreviation;
  final String name;
  final String meta;
  final int difficulty;
  final bool isCombo;
  final VoidCallback onTap;

  const _EditPickerRow({
    required this.abbreviation,
    required this.name,
    required this.meta,
    required this.difficulty,
    required this.isCombo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isCombo ? const Color(0xFFF7F5FE) : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(color: isCombo ? const Color(0xFFE5E0FB) : AppColors.line),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCombo ? const Color(0xFFEDE9FE) : AppColors.chipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isCombo
                      ? const Icon(Icons.layers, size: 18, color: AppColors.noTouchText)
                      : Text(
                          abbreviation ?? '?',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.indigo),
                        ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DifficultyChip(difficulty),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditSlot extends StatelessWidget {
  final _SlotItem slot;
  final VoidCallback onRemove;
  final ValueChanged<bool> onToggleStrongFoot;
  final ValueChanged<bool> onToggleNoTouch;

  const _EditSlot({
    required this.slot,
    required this.onRemove,
    required this.onToggleStrongFoot,
    required this.onToggleNoTouch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.indigoTint, borderRadius: BorderRadius.circular(9)),
            child: Text(
              '${slot.position}',
              style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.indigo),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.trickName,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  slot.abbreviation,
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (!slot.isTransition) ...[
            FootToggle(
              value: slot.strongFoot,
              onTap: () => onToggleStrongFoot(!slot.strongFoot),
            ),
            const SizedBox(width: 6),
            _EditFlagToggle(
              label: 'NT',
              active: slot.noTouch,
              enabled: slot.crossOver,
              onTap: slot.crossOver ? () => onToggleNoTouch(!slot.noTouch) : null,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _EditFlagToggle extends StatelessWidget {
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  const _EditFlagToggle({required this.label, required this.active, this.enabled = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.indigoTint : Colors.transparent;
    final fg = !enabled ? AppColors.faint : (active ? AppColors.indigo : AppColors.muted);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
      ),
    );
  }
}

class _EditSubComboSlot extends StatelessWidget {
  final _SlotItem slot;
  final VoidCallback onRemove;

  const _EditSubComboSlot({required this.slot, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.noTouchBg,
        border: Border.all(color: const Color(0xFFE5E0FB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(9)),
            child: Text(
              '${slot.position}',
              style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.noTouchText),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(6)),
            child: Text(
              'COMBO',
              style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.noTouchText, letterSpacing: 0.4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slot.subComboName ?? '',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${slot.subComboTricks?.length ?? 0} tricks',
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

