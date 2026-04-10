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
  final VoidCallback? onDeleted;

  const ComboCard({
    super.key,
    required this.combo,
    this.showActions = false,
    this.onRefresh,
    this.onDeleted,
  });

  @override
  State<ComboCard> createState() => _ComboCardState();
}

class _ComboCardState extends State<ComboCard> {
  bool _visibilityLoading = false;
  bool _deleteLoading = false;
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

  Future<void> _toggleVisibility() async {
    setState(() => _visibilityLoading = true);
    try {
      await ApiClient.instance
          .setVisibility(widget.combo.id, !(widget.combo.isPublic ?? false));
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

  Future<void> _deleteCombo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete combo?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleteLoading = true);
    try {
      await ApiClient.instance.deleteCombo(widget.combo.id);
      widget.onDeleted?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _deleteLoading = false);
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
    final canDelete = AuthService.instance.isAdmin || isOwner;
    final colorScheme = Theme.of(context).colorScheme;

    final authed = AuthService.instance.userId != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/combos/${combo.id}'),
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
                      if (combo.isPublic != null) ...[
                        const SizedBox(height: 4),
                        _Chip(
                          label: combo.isPublic! ? 'Public' : 'Private',
                          color: combo.isPublic!
                              ? colorScheme.primaryContainer
                              : null,
                        ),
                      ],
                      if (combo.averageRating > 0) ...[
                        const SizedBox(height: 4),
                        _Chip(
                          label:
                              '★ ${combo.averageRating.toStringAsFixed(1)} (${combo.totalRatings})',
                          color: Colors.amber.shade100,
                        ),
                      ],
                      if (_favoured) ...[
                        const SizedBox(height: 4),
                        _Chip(label: '♥ Favourite', color: Colors.pink.shade50),
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
                        '${t.position}. ${t.abbreviation}${t.noTouch ? '(nt)' : ''}',
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
                    if (authed)
                      OutlinedButton.icon(
                        onPressed: _favLoading ? null : _toggleFavourite,
                        icon: Icon(
                          _favoured ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: _favoured ? Colors.pink : null,
                        ),
                        label: Text(_favoured ? 'Unfavourite' : 'Favourite'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _favoured ? Colors.pink : null,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      ),
                    if (!isOwner && currentUserId != null)
                      OutlinedButton.icon(
                        onPressed: _openRating,
                        icon: const Icon(Icons.star_outline, size: 16),
                        label: const Text('Rate'),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4)),
                      ),
                    if (isOwner) ...[
                      OutlinedButton.icon(
                        onPressed: _visibilityLoading ? null : _toggleVisibility,
                        icon: Icon(
                          combo.isPublic == true
                              ? Icons.lock_outline
                              : Icons.public,
                          size: 16,
                        ),
                        label: Text(
                            combo.isPublic == true ? 'Make private' : 'Make public'),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4)),
                      ),
                    ],
                    if (canDelete) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _deleteLoading ? null : _deleteCombo,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      ),
                    ],
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
