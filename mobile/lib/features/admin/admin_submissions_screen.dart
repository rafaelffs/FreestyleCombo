import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/models/combo.dart';
import '../../core/models/trick_submission.dart';

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
      appBar: AppBar(
        title: const Text('Approvals'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Combo Publication Requests', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FutureBuilder<List<ComboDto>>(
                future: _comboFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    );
                  }
                  final combos = snapshot.data ?? [];
                  if (combos.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No combos pending review.'),
                    );
                  }
                  return Column(
                    children: combos.map((combo) {
                      final busy = _processing.contains(combo.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (combo.name != null && combo.name!.isNotEmpty)
                                  Text(combo.name!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text(
                                  combo.displayText,
                                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'by ${combo.ownerUserName ?? '?'} · avg diff ${combo.averageDifficulty.toStringAsFixed(1)} · ${combo.trickCount} tricks',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => _act(combo.id, () => ApiClient.instance.approveComboVisibility(combo.id)),
                                      child: busy
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Text('Approve'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                      onPressed: busy
                                          ? null
                                          : () => _act(combo.id, () => ApiClient.instance.rejectComboVisibility(combo.id)),
                                      child: const Text('Reject'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text('Trick Submissions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FutureBuilder<List<TrickSubmissionDto>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    );
                  }
                  final submissions = snapshot.data ?? [];
                  if (submissions.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No pending submissions.'),
                    );
                  }
                  return Column(
                    children: submissions.map((s) {
                      final busy = _processing.contains(s.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('Pending', style: TextStyle(color: Colors.orange[800], fontSize: 12)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${s.abbreviation} · by ${s.submittedByUserName} · ${s.submittedAt.toLocal().toString().substring(0, 10)}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 4,
                                  children: [
                                    _stat('Revs', s.revolution.toString()),
                                    _stat('Difficulty', '${s.difficulty}'),
                                    _stat('Common Lvl', '${s.commonLevel}'),
                                    _stat('CrossOver', s.crossOver ? 'Yes' : 'No'),
                                    _stat('Knee', s.knee ? 'Yes' : 'No'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => _act(s.id, () => ApiClient.instance.approveSubmission(s.id)),
                                      child: busy
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Text('Approve'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                      onPressed: busy
                                          ? null
                                          : () => _act(s.id, () => ApiClient.instance.rejectSubmission(s.id)),
                                      child: const Text('Reject'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
