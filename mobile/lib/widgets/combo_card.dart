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
                    child: Text(
                      combo.displayText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
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
                    ],
                  ),
                ],
              ),
              if (combo.ownerEmail != null) ...[
                const SizedBox(height: 4),
                Text(
                  'by ${combo.ownerEmail}',
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
                Row(
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
