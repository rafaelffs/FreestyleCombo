import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';
import '../../widgets/rate_combo_dialog.dart';

class ComboDetailScreen extends StatefulWidget {
  final String id;
  const ComboDetailScreen({super.key, required this.id});

  @override
  State<ComboDetailScreen> createState() => _ComboDetailScreenState();
}

class _ComboDetailScreenState extends State<ComboDetailScreen> {
  late Future<ComboDto> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ApiClient.instance.getComboById(widget.id);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Combo Detail')),
      body: FutureBuilder<ComboDto>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          final combo = snap.data!;
          final currentUserId = AuthService.instance.userId;
          final isOwner = combo.ownerId == currentUserId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  combo.displayText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (combo.ownerEmail != null)
                      Text('by ${combo.ownerEmail}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(width: 8),
                    Text(
                      combo.createdAt.substring(0, 10),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Badges
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                        label: Text(
                            'Avg diff: ${combo.averageDifficulty.toStringAsFixed(1)}')),
                    Chip(label: Text('${combo.trickCount} tricks')),
                    if (combo.isPublic != null)
                      Chip(
                          label:
                              Text(combo.isPublic! ? 'Public' : 'Private')),
                    if (combo.averageRating > 0)
                      Chip(
                          label: Text(
                              '★ ${combo.averageRating.toStringAsFixed(1)} (${combo.totalRatings})')),
                  ],
                ),

                // AI Description
                if (combo.aiDescription != null &&
                    combo.aiDescription!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                          left: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3)),
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                    ),
                    child: Text(
                      combo.aiDescription!,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],

                // Trick table
                if (combo.tricks != null && combo.tricks!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Tricks',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Table(
                      columnWidths: const {
                        0: IntrinsicColumnWidth(),
                        1: FlexColumnWidth(2),
                        2: IntrinsicColumnWidth(),
                        3: IntrinsicColumnWidth(),
                        4: IntrinsicColumnWidth(),
                        5: IntrinsicColumnWidth(),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                              color: Colors.grey[100]),
                          children: const [
                            _TH('#'),
                            _TH('Name'),
                            _TH('Abbr.'),
                            _TH('Diff'),
                            _TH('Foot'),
                            _TH('NT'),
                          ],
                        ),
                        ...combo.tricks!.map((t) => TableRow(
                              children: [
                                _TD(t.position.toString()),
                                _TD(t.name),
                                _TD(t.abbreviation,
                                    mono: true),
                                _TD(t.difficulty.toString()),
                                _TD(t.strongFoot ? 'S' : 'W'),
                                _TD(t.noTouch ? '✓' : '—'),
                              ],
                            )),
                      ],
                    ),
                  ),
                ],

                // Actions
                if (!isOwner && currentUserId != null) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _openRating(combo.id),
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Rate this combo'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _TD extends StatelessWidget {
  final String text;
  final bool mono;
  const _TD(this.text, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontFamily: mono ? 'monospace' : null,
        ),
      ),
    );
  }
}
