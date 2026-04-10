import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';

class TricksScreen extends StatefulWidget {
  const TricksScreen({super.key});

  @override
  State<TricksScreen> createState() => _TricksScreenState();
}

class _TricksScreenState extends State<TricksScreen> {
  List<TrickDto> _tricks = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tricks = await ApiClient.instance.getTricks();
      setState(() => _tricks = tricks);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTrick(TrickDto trick) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete trick?'),
        content: Text('Delete "${trick.name}"? This will fail if the trick is used in any combo.'),
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
    try {
      await ApiClient.instance.deleteTrick(trick.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _openEdit(TrickDto trick) {
    showDialog<void>(
      context: context,
      builder: (_) => _EditTrickDialog(
        trick: trick,
        onSaved: _load,
      ),
    );
  }

  List<TrickDto> get _filtered {
    final q = _search.toLowerCase();
    if (q.isEmpty) return _tricks;
    return _tricks
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.abbreviation.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final admin = AuthService.instance.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tricks'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or abbreviation…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final t = _filtered[i];
                      return ListTile(
                        title: Text(t.name),
                        subtitle: Text(
                          '${t.abbreviation} · motion ${t.motion}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _DiffChip(difficulty: t.difficulty),
                            const SizedBox(width: 4),
                            if (t.crossOver)
                              const _Tag(label: 'CO', color: Colors.indigo),
                            if (t.knee)
                              const _Tag(label: 'K', color: Colors.teal),
                            if (admin) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _openEdit(t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                onPressed: () => _deleteTrick(t),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final int difficulty;
  const _DiffChip({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    if (difficulty <= 4) {
      bg = Colors.green.shade100;
      fg = Colors.green.shade800;
    } else if (difficulty <= 7) {
      bg = Colors.yellow.shade100;
      fg = Colors.yellow.shade900;
    } else {
      bg = Colors.red.shade100;
      fg = Colors.red.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        '$difficulty',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _EditTrickDialog extends StatefulWidget {
  final TrickDto trick;
  final VoidCallback onSaved;

  const _EditTrickDialog({required this.trick, required this.onSaved});

  @override
  State<_EditTrickDialog> createState() => _EditTrickDialogState();
}

class _EditTrickDialogState extends State<_EditTrickDialog> {
  late final _nameCtrl = TextEditingController(text: widget.trick.name);
  late final _abbrevCtrl = TextEditingController(text: widget.trick.abbreviation);
  late double _motion = widget.trick.motion;
  late int _difficulty = widget.trick.difficulty;
  late int _commonLevel = widget.trick.commonLevel;
  late bool _crossOver = widget.trick.crossOver;
  late bool _knee = widget.trick.knee;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrevCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final updated = TrickDto(
        id: widget.trick.id,
        name: _nameCtrl.text.trim(),
        abbreviation: _abbrevCtrl.text.trim(),
        crossOver: _crossOver,
        knee: _knee,
        motion: _motion,
        difficulty: _difficulty,
        commonLevel: _commonLevel,
      );
      await ApiClient.instance.updateTrick(widget.trick.id, updated);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Trick'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _abbrevCtrl,
              decoration: const InputDecoration(labelText: 'Abbreviation'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    label: 'Motion',
                    value: _motion,
                    min: 0.5,
                    max: 10,
                    onChanged: (v) => setState(() => _motion = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumField(
                    label: 'Difficulty',
                    value: _difficulty.toDouble(),
                    min: 1,
                    max: 10,
                    onChanged: (v) => setState(() => _difficulty = v.round()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumField(
                    label: 'Level',
                    value: _commonLevel.toDouble(),
                    min: 1,
                    max: 10,
                    onChanged: (v) => setState(() => _commonLevel = v.round()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _crossOver,
                  onChanged: (v) => setState(() => _crossOver = v ?? false),
                ),
                const Text('CrossOver'),
                const SizedBox(width: 16),
                Checkbox(
                  value: _knee,
                  onChanged: (v) => setState(() => _knee = v ?? false),
                ),
                const Text('Knee'),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _NumField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value.toString()),
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null && parsed >= min && parsed <= max) onChanged(parsed);
      },
    );
  }
}
