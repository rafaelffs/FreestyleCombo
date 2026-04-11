import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api/api_client.dart';
import '../core/auth/auth_service.dart';
import '../core/models/combo.dart';
import 'rate_combo_dialog.dart';

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
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _favoured = widget.combo.isFavourited;
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

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(description, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(_, true),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

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
    final colorScheme = Theme.of(context).colorScheme;
    final visibilityState = combo.visibility == 'PendingReview'
        ? 'pending'
        : (combo.visibility == 'Public' || combo.isPublic == true)
            ? 'public'
            : 'private';
    final canActOnVisibility =
        (isOwner && visibilityState == 'private') ||
        (isOwner && visibilityState == 'pending') ||
        (isAdmin && visibilityState == 'public');
    final showGlobe = isOwner || isAdmin;

    final authed = AuthService.instance.userId != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/combos/${combo.id}').then((_) => widget.onRefresh?.call()),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        Row(
                          children: [
                            if (authed)
                              Tooltip(
                                message: _favoured ? 'Unfavourite' : 'Favourite',
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: OutlinedButton(
                                    onPressed: _favLoading ? null : _toggleFavourite,
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(34, 34),
                                      side: BorderSide(color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Icon(
                                      _favoured ? Icons.favorite : Icons.favorite_border,
                                      color: _favoured ? Colors.pink : Colors.grey,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            if (widget.showActions && !isOwner && currentUserId != null) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Rate this combo',
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: OutlinedButton(
                                    onPressed: _openRating,
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(34, 34),
                                      side: BorderSide(color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(Icons.star, color: Colors.grey.shade300, size: 18),
                                        Icon(Icons.star_half, color: Colors.amber, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (showGlobe) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: visibilityState == 'pending'
                                    ? (isOwner ? 'Cancel review request' : 'Pending approval')
                                    : visibilityState == 'public'
                                        ? (isAdmin ? 'Make private' : 'Public')
                                        : (isAdmin ? 'Set public' : 'Submit for review'),
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: OutlinedButton(
                                    onPressed: (_visibilityLoading || !canActOnVisibility)
                                        ? null
                                        : () => _handleVisibilityTap(visibilityState),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(34, 34),
                                      side: BorderSide(color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.public,
                                      size: 18,
                                      color: visibilityState == 'pending'
                                          ? Colors.amber.shade700
                                          : visibilityState == 'public'
                                              ? colorScheme.primary
                                              : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (combo.name != null && combo.name!.isNotEmpty)
                          Text(
                            combo.name!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          )
                        else
                          Text(
                            combo.displayText,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Chip(
                          label:
                              'Diff: ${combo.averageDifficulty.toStringAsFixed(1)}'),
                      if (combo.averageRating > 0) ...[
                        const SizedBox(height: 4),
                        _Chip(
                          label:
                              '★ ${combo.averageRating.toStringAsFixed(1)} (${combo.totalRatings})',
                          color: Colors.amber.shade100,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (combo.ownerUserName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'by ${combo.ownerUserName}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
              if (combo.tricks != null && combo.tricks!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final tricks = combo.tricks!;
                  final hasMore = tricks.length > _tricksLimit;
                  final visible = _expanded ? tricks : tricks.take(_tricksLimit).toList();
                  return Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...visible.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${t.position}. ${t.abbreviation}${t.noTouch ? '(nt)' : ''}${!t.strongFoot ? '(wf)' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      )),
                      if (hasMore)
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _expanded ? 'Show less' : '+${tricks.length - _tricksLimit} more',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
              ],
              if (combo.aiDescription != null &&
                  combo.aiDescription!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '"${combo.aiDescription}"',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;

  const _Chip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
