import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api/api_client.dart';
import '../core/auth/auth_service.dart';
import '../core/models/combo.dart';
import '../theme/app_colors.dart';
import 'confirm_sheet.dart';
import 'difficulty_chip.dart';
import 'rate_combo_dialog.dart';

/// Whether combo trick sequences (card titles, chips) show full trick names
/// instead of abbreviations. A plain static flag, matching this app's
/// existing manual-singleton pattern — toggled from the combos list header,
/// read fresh on every ComboCard build.
class TrickNameDisplay {
  TrickNameDisplay._();
  static bool showFullName = false;

  /// A transition trick (e.g. "Combo") is a short connector label, not a
  /// move worth expanding — it always shows its abbreviation, regardless of
  /// the full-name/abbreviation toggle.
  static String label({required bool isTransition, required String? name, required String? abbreviation}) {
    if (isTransition) return abbreviation ?? name ?? '?';
    return (showFullName ? name : abbreviation) ?? '?';
  }
}

/// Formats the trick list as "(ABBR)(nt) (ABBR) (SubCombo)…" — each trick
/// wrapped in parentheses, with "(nt)" appended right after any no-touch
/// trick. Returns null when there's nothing to format (caller falls back to
/// combo.displayText).
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

class ComboCard extends StatefulWidget {
  final ComboDto combo;
  final bool showActions;
  final VoidCallback? onRefresh;

  const ComboCard({
    super.key,
    required this.combo,
    this.showActions = false,
    this.onRefresh,
  });

  @override
  State<ComboCard> createState() => _ComboCardState();
}

const int _tricksLimit = 6;

class _ComboCardState extends State<ComboCard> {
  bool _visibilityLoading = false;
  bool _favLoading = false;
  late bool _favoured;
  bool _completedLoading = false;
  late bool _completed;
  late int _completionCount;
  bool _personalReusableLoading = false;
  late bool _isPersonalReusable;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _favoured = widget.combo.isFavourited;
    _completed = widget.combo.isCompleted;
    _completionCount = widget.combo.completionCount;
    _isPersonalReusable = widget.combo.isPersonalReusable;
  }

  Future<void> _toggleFavourite() async {
    setState(() => _favLoading = true);
    try {
      if (_favoured) {
        await ApiClient.instance.removeFavourite(widget.combo.id);
      } else {
        await ApiClient.instance.addFavourite(widget.combo.id);
      }
      setState(() => _favoured = !_favoured);
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Future<void> _toggleCompleted() async {
    setState(() => _completedLoading = true);
    try {
      if (_completed) {
        await ApiClient.instance.unmarkCompleted(widget.combo.id);
        setState(() {
          _completed = false;
          _completionCount = (_completionCount - 1).clamp(0, 999999);
        });
      } else {
        await ApiClient.instance.markCompleted(widget.combo.id);
        setState(() {
          _completed = true;
          _completionCount = _completionCount + 1;
        });
      }
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _completedLoading = false);
    }
  }

  Future<void> _togglePersonalReusable() async {
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
        await ApiClient.instance.removePersonalReusable(widget.combo.id);
      } else {
        await ApiClient.instance.addPersonalReusable(widget.combo.id);
      }
      setState(() => _isPersonalReusable = !_isPersonalReusable);
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _personalReusableLoading = false);
    }
  }

  Future<void> _handleVisibilityTap(String visibilityState) async {
    final isAdmin = AuthService.instance.isAdmin;
    final isOwner = widget.combo.ownerId == AuthService.instance.userId;

    String title;
    String description;
    String confirmLabel;
    bool setPublic;

    if (visibilityState == 'private') {
      title = isAdmin ? 'Set combo public?' : 'Submit for review?';
      description = isAdmin
          ? 'This combo will be visible to everyone and moved to the Public tab.'
          : 'This combo will be sent for admin approval. Once approved it will appear in the Public tab and be removed from your Mine list.';
      confirmLabel = isAdmin ? 'Set public' : 'Submit';
      setPublic = true;
    } else if (visibilityState == 'pending' && isOwner) {
      title = 'Cancel review request?';
      description = 'The combo will return to private and reappear in your Mine list.';
      confirmLabel = 'Cancel request';
      setPublic = false;
    } else if (visibilityState == 'public' && isAdmin) {
      title = 'Make combo private?';
      description = 'This combo will be hidden from the public list.';
      confirmLabel = 'Make private';
      setPublic = false;
    } else {
      return;
    }

    final confirmed = await showConfirmSheet(
      context,
      title: title,
      description: description,
      confirmLabel: confirmLabel,
    );
    if (!confirmed) return;

    setState(() => _visibilityLoading = true);
    try {
      await ApiClient.instance.setVisibility(widget.combo.id, setPublic);
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _visibilityLoading = false);
    }
  }

  void _openRating() {
    showDialog<void>(
      context: context,
      builder: (_) => RateComboDialog(
        comboId: widget.combo.id,
        onRated: () => widget.onRefresh?.call(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final combo = widget.combo;
    final currentUserId = AuthService.instance.userId;
    final isOwner = combo.ownerId == currentUserId;
    final isAdmin = AuthService.instance.isAdmin;
    final authed = currentUserId != null;
    final visibilityState = combo.visibility == 'PendingReview'
        ? 'pending'
        : (combo.visibility == 'Public' || combo.isPublic == true)
            ? 'public'
            : 'private';
    final canActOnVisibility = (isOwner && visibilityState == 'private') ||
        (isOwner && visibilityState == 'pending') ||
        (isAdmin && visibilityState == 'public');
    final canRate = widget.showActions && !isOwner && currentUserId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -16,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/combos/${combo.id}').then((_) => widget.onRefresh?.call()),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (authed) ...[
                  Row(
                    children: [
                      _IconToggle(
                        icon: _favoured ? Icons.favorite : Icons.favorite_border,
                        color: _favoured ? AppColors.pink : AppColors.faint,
                        loading: _favLoading,
                        tooltip: _favoured ? 'Unfavourite' : 'Favourite',
                        onTap: _toggleFavourite,
                      ),
                      const SizedBox(width: 8),
                      _IconToggle(
                        icon: _completed ? Icons.check_circle : Icons.check_circle_outline,
                        color: _completed ? AppColors.green : AppColors.faint,
                        loading: _completedLoading,
                        tooltip: _completed ? 'Mark as not done' : 'Mark as done',
                        onTap: _toggleCompleted,
                        label: _completionCount > 0 ? '$_completionCount' : null,
                      ),
                      if (isOwner || visibilityState == 'public' || isAdmin) ...[
                        const SizedBox(width: 8),
                        _IconToggle(
                          icon: _isPersonalReusable ? Icons.link : Icons.link_off,
                          color: _isPersonalReusable ? AppColors.indigo : AppColors.faint,
                          loading: _personalReusableLoading,
                          tooltip: _isPersonalReusable
                              ? 'Remove from your trick list'
                              : 'List combo in the trick list',
                          onTap: _togglePersonalReusable,
                        ),
                      ],
                      if (canRate) ...[
                        const SizedBox(width: 8),
                        _IconToggle(
                          icon: Icons.star_rounded,
                          color: AppColors.star,
                          tooltip: 'Rate this combo',
                          onTap: () {
                            _openRating();
                            return Future.value();
                          },
                          label: combo.averageRating > 0
                              ? combo.averageRating.toStringAsFixed(1)
                              : null,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (combo.name != null && combo.name!.isNotEmpty)
                                ? combo.name!
                                : _formatSequence(combo.tricks) ?? combo.displayText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: (combo.name != null && combo.name!.isNotEmpty)
                                ? GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                    color: AppColors.ink,
                                  )
                                : GoogleFonts.jetBrainsMono(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                          ),
                          if (combo.ownerUserName != null) ...[
                            const SizedBox(height: 3),
                            _OwnerLine(combo: combo),
                          ],
                        ],
                      ),
                    ),
                    if (DifficultyDisplay.show) ...[
                      const SizedBox(width: 12),
                      _DiffBadge(value: combo.totalDifficulty.toInt()),
                    ],
                  ],
                ),
                if (combo.tricks != null && combo.tricks!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _TrickChips(
                    tricks: combo.tricks!,
                    expanded: _expanded,
                    onToggleExpanded: () => setState(() => _expanded = !_expanded),
                  ),
                ],
                if (combo.aiDescription != null && combo.aiDescription!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '"${combo.aiDescription}"',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.muted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                Container(
                  margin: const EdgeInsets.only(top: 15),
                  padding: const EdgeInsets.only(top: 14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    children: [
                      if (combo.totalRatings > 0)
                        _MiniStat(
                          icon: Icons.star_rounded,
                          color: AppColors.star,
                          label: combo.averageRating.toStringAsFixed(1),
                        ),
                      if (combo.totalRatings > 0) const SizedBox(width: 12),
                      _MiniStat(
                        icon: Icons.check_circle_rounded,
                        color: AppColors.green,
                        label: '$_completionCount',
                      ),
                      const Spacer(),
                      _VisibilityTag(
                        state: visibilityState,
                        loading: _visibilityLoading,
                        actionable: canActOnVisibility,
                        onTap: () => _handleVisibilityTap(visibilityState),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerLine extends StatelessWidget {
  final ComboDto combo;
  const _OwnerLine({required this.combo});

  @override
  Widget build(BuildContext context) {
    final ownerId = combo.ownerId;
    final byStyle = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
    );
    final nameStyle = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.indigo,
    );
    final text = RichText(
      text: TextSpan(
        children: [
          TextSpan(text: 'by ', style: byStyle),
          TextSpan(text: combo.ownerUserName, style: nameStyle),
        ],
      ),
    );
    return GestureDetector(
      onTap: () => context.push('/users/$ownerId'),
      child: text,
    );
  }
}

class _DiffBadge extends StatelessWidget {
  final int value;
  const _DiffBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.grad,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'DIFF',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrickChips extends StatelessWidget {
  final List<ComboTrickDto> tricks;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  const _TrickChips({
    required this.tricks,
    required this.expanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final hasMore = tricks.length > _tricksLimit;
    final visible = expanded ? tricks : tricks.take(_tricksLimit).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in visible) _buildChip(t),
        if (hasMore)
          GestureDetector(
            onTap: onToggleExpanded,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                expanded ? 'Show less' : '+${tricks.length - _tricksLimit}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChip(ComboTrickDto t) {
    // Always abbreviated — this dense per-trick chip row stays compact
    // regardless of the full-name/abbreviation toggle, which only affects
    // the card's headline sequence (_formatSequence).
    final label = t.type == 'combo' ? (t.subComboName ?? 'Combo') : (t.abbreviation ?? '?');
    final suffix = t.isTransition ? '' : (t.noTouch ? '·nt' : (!t.strongFoot ? '·wf' : ''));
    final isNoTouch = t.noTouch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isNoTouch ? AppColors.noTouchBg : AppColors.chipBg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${t.position}. ',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.faint,
              ),
            ),
            TextSpan(
              text: '$label$suffix',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isNoTouch ? AppColors.noTouchText : AppColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _MiniStat({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _VisibilityTag extends StatelessWidget {
  final String state; // private | pending | public
  final bool loading;
  final bool actionable;
  final VoidCallback onTap;

  const _VisibilityTag({
    required this.state,
    required this.loading,
    required this.actionable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    late String label;
    switch (state) {
      case 'public':
        bg = const Color(0xFFE0EAFE);
        fg = const Color(0xFF2563EB);
        label = 'Public';
      case 'pending':
        bg = AppColors.amberBg;
        fg = AppColors.amber;
        label = 'Pending';
      default:
        bg = const Color(0xFFEEEDF4);
        fg = AppColors.muted;
        label = 'Private';
    }

    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: loading
          ? SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: fg),
            )
          : Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: fg,
              ),
            ),
    );

    if (!actionable) return tag;
    return GestureDetector(onTap: loading ? null : onTap, child: tag);
  }
}

class _IconToggle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool loading;
  final String tooltip;
  final Future<void> Function() onTap;
  final String? label;

  const _IconToggle({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: loading ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.symmetric(horizontal: label != null ? 8 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                if (label != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    label!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
