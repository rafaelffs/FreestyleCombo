import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/models/combo.dart';

class AdminComboReviewsScreen extends StatefulWidget {
  const AdminComboReviewsScreen({super.key});

  @override
  State<AdminComboReviewsScreen> createState() => _AdminComboReviewsScreenState();
}

class _AdminComboReviewsScreenState extends State<AdminComboReviewsScreen> {
  late Future<List<ComboDto>> _future;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ApiClient.instance.getPendingComboReviews();
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
      if (mounted) setState(() => _processing.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Combo Reviews')),
      body: FutureBuilder<List<ComboDto>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          final combos = snap.data!;
          if (combos.isEmpty) {
            return const Center(child: Text('No combos pending review.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: combos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final combo = combos[i];
              final loading = _processing.contains(combo.id);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (combo.name != null && combo.name!.isNotEmpty)
                        Text(combo.name!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(combo.displayText,
                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('by ${combo.ownerUserName ?? '?'} · avg diff ${combo.averageDifficulty.toStringAsFixed(1)} · ${combo.trickCount} tricks',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      if (combo.tricks != null && combo.tricks!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: combo.tricks!.map((t) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                '${t.position}. ${t.abbreviation}${t.noTouch ? '(nt)' : ''}${!t.strongFoot ? '(wf)' : ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: loading ? null : () => _act(combo.id, () => ApiClient.instance.approveComboVisibility(combo.id)),
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                            child: const Text('Approve'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: loading ? null : () => _act(combo.id, () => ApiClient.instance.rejectComboVisibility(combo.id)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Reject'),
                          ),
                          if (loading) ...[
                            const SizedBox(width: 12),
                            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
