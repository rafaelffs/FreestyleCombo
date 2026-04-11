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

class _ComboCardState extends State<ComboCard> {
  bool _visibilityLoading = false;
  bool _favLoading = false;
  late bool _favoured;

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

  Future<void> _submitForReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit for review?'),
        content: const Text(
          'This will set the combo as public and send it for admin approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _visibilityLoading = true);
    try {
      await ApiClient.instance.setVisibility(widget.combo.id, true);
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
    final colorScheme = Theme.of(context).colorScheme;
    final visibilityState = combo.visibility == 'PendingReview'
      ? 'pending'
      : (combo.visibility == 'Public' || combo.isPublic == true)
        ? 'public'
        : 'private';

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
                            if (isOwner) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: visibilityState == 'pending'
                                    ? 'Pending approval'
                                    : visibilityState == 'public'
                                        ? 'Public'
                                        : 'Private',
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: OutlinedButton(
                                    onPressed: _visibilityLoading
                                        ? null
                                        : () {
                                            if (visibilityState == 'private') {
                                              _submitForReview();
                                            }
                                          },
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
                          ),
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
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: combo.tricks!.map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${t.position}. ${t.abbreviation}${t.noTouch ? '(nt)' : ''}${!t.strongFoot ? '(wf)' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
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
              if (widget.showActions) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (!isOwner && currentUserId != null)
                      OutlinedButton.icon(
                        onPressed: _openRating,
                        icon: const Icon(Icons.star_outline, size: 16),
                        label: const Text('Rate'),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4)),
                      ),
                  ],
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
