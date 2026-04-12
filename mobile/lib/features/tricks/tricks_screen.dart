import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';

enum _SortKey { abbreviation, name, revolution, difficulty }

class TricksScreen extends StatefulWidget {
  const TricksScreen({super.key});

  @override
  State<TricksScreen> createState() => _TricksScreenState();
}

class _TricksScreenState extends State<TricksScreen> {
  List<TrickDto> _tricks = [];
  bool _loading = true;
  String? _error;

  // Filters
  final _searchCtrl = TextEditingController();
  String _search = '';
  int? _minDiff;
  int? _maxDiff;
  Set<double> _selectedRevs = {};

  // Sort
  _SortKey _sortKey = _SortKey.abbreviation;
  bool _sortAsc = true;

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
    setState(() { _loading = true; _error = null; });
    try {
      final tricks = await ApiClient.instance.getTricks();
      if (mounted) setState(() => _tricks = tricks);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTrick(TrickDto trick) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete trick?'),
        content: Text('Delete "${trick.name}"? This will fail if used in any combo.'),
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

  void _openSubmit() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InlineSubmitForm(
        onSubmitted: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trick submitted for review!')),
          );
        },
      ),
    );
  }

  void _openEdit(TrickDto trick) {
    showDialog<void>(
      context: context,
      builder: (_) => _EditTrickDialog(trick: trick, onSaved: _load),
    );
  }

  List<double> get _revOptions {
    final revs = _tricks.map((t) => t.revolution).toSet().toList()..sort();
    return revs;
  }

  void _showRevFilter() {
    final revOptions = _revOptions;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Text('Filter by Revolutions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_selectedRevs.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedRevs = {});
                          setSt(() {});
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: revOptions.map((rev) {
                    final selected = _selectedRevs.contains(rev);
                    return CheckboxListTile(
                      dense: true,
                      title: Text('${rev % 1 == 0 ? rev.toInt() : rev} rev${rev == 1 ? '' : 's'}'),
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedRevs = {..._selectedRevs, rev};
                          } else {
                            _selectedRevs = _selectedRevs.where((r) => r != rev).toSet();
                          }
                        });
                        setSt(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TrickDto> get _filtered {
    final q = _search.toLowerCase();
    var list = _tricks.where((t) {
      if (q.isNotEmpty &&
          !t.name.toLowerCase().contains(q) &&
          !t.abbreviation.toLowerCase().contains(q)) return false;
      if (_minDiff != null && t.difficulty < _minDiff!) return false;
      if (_maxDiff != null && t.difficulty > _maxDiff!) return false;
      if (_selectedRevs.isNotEmpty && !_selectedRevs.contains(t.revolution)) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case _SortKey.abbreviation:
          cmp = a.abbreviation.compareTo(b.abbreviation);
        case _SortKey.name:
          cmp = a.name.compareTo(b.name);
        case _SortKey.revolution:
          cmp = a.revolution.compareTo(b.revolution);
        case _SortKey.difficulty:
          cmp = a.difficulty.compareTo(b.difficulty);
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  void _setSort(_SortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
  }

  Widget _sortChip(_SortKey key, String label) {
    final active = _sortKey == key;
    return GestureDetector(
      onTap: () => _setSort(key),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.indigo.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? Colors.indigo.shade600 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : Colors.grey.shade700,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 3),
              Icon(
                _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = AuthService.instance.isAdmin;
    final authed = AuthService.instance.isAuthenticated;
    final filtered = _filtered;
    final revsLabel = _selectedRevs.isEmpty
        ? 'Revs'
        : _selectedRevs.length == 1
            ? '${_selectedRevs.first % 1 == 0 ? _selectedRevs.first.toInt() : _selectedRevs.first} rev'
            : 'Revs (${_selectedRevs.length})';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tricks'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: authed
          ? FloatingActionButton.extended(
              onPressed: _openSubmit,
              icon: const Icon(Icons.add),
              label: const Text('Submit Trick'),
            )
          : null,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or abbreviation…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
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

          // Filters row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                // Min diff
                SizedBox(
                  width: 72,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Min diff',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(
                        () => _minDiff = int.tryParse(v)),
                  ),
                ),
                const SizedBox(width: 8),
                // Max diff
                SizedBox(
                  width: 72,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Max diff',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(
                        () => _maxDiff = int.tryParse(v)),
                  ),
                ),
                const SizedBox(width: 8),
                // Revolutions filter chip
                GestureDetector(
                  onTap: _showRevFilter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedRevs.isNotEmpty
                          ? Colors.indigo.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedRevs.isNotEmpty
                            ? Colors.indigo.shade300
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          revsLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: _selectedRevs.isNotEmpty
                                ? Colors.indigo.shade700
                                : Colors.grey.shade700,
                            fontWeight: _selectedRevs.isNotEmpty
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.expand_more,
                            size: 14,
                            color: _selectedRevs.isNotEmpty
                                ? Colors.indigo.shade700
                                : Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sort chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              children: [
                _sortChip(_SortKey.abbreviation, 'Abbrev'),
                _sortChip(_SortKey.name, 'Name'),
                _sortChip(_SortKey.difficulty, 'Diff'),
                _sortChip(_SortKey.revolution, 'Revs'),
              ],
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          // Tricks list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Text('No tricks found.',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final t = filtered[i];
                          return ListTile(
                            dense: true,
                            title: Row(
                              children: [
                                Text(
                                  t.abbreviation,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.name,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.normal),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${t.revolution % 1 == 0 ? t.revolution.toInt() : t.revolution} revs',
                              style: const TextStyle(fontSize: 11),
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
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _openEdit(t),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
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

// ── Shared widgets ─────────────────────────────────────────────────────────────

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
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Submit form ────────────────────────────────────────────────────────────────

class _InlineSubmitForm extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _InlineSubmitForm({required this.onSubmitted});

  @override
  State<_InlineSubmitForm> createState() => _InlineSubmitFormState();
}

class _InlineSubmitFormState extends State<_InlineSubmitForm> {
  final _nameCtrl = TextEditingController();
  final _abbrevCtrl = TextEditingController();
  double _revolution = 1;
  int _difficulty = 1;
  int _commonLevel = 5;
  bool _crossOver = false;
  bool _knee = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrevCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _abbrevCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name and abbreviation are required.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.submitTrick(
        name: _nameCtrl.text.trim(),
        abbreviation: _abbrevCtrl.text.trim(),
        crossOver: _crossOver,
        knee: _knee,
        revolution: _revolution,
        difficulty: _difficulty,
        commonLevel: _commonLevel,
      );
      if (mounted) widget.onSubmitted();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
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
          const SizedBox(height: 16),
          const Text('Submit a Trick',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _abbrevCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Abbreviation', hintText: 'e.g. CO'),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Name', hintText: 'e.g. Crossover'),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Revs', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Text(_revolution.toStringAsFixed(1),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12)),
            Expanded(
              child: Slider(
                value: _revolution,
                min: 0.5,
                max: 10,
                divisions: 19,
                onChanged: (v) => setState(() => _revolution = v),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Diff', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Text('$_difficulty',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12)),
            Expanded(
              child: Slider(
                value: _difficulty.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (v) => setState(() => _difficulty = v.round()),
              ),
            ),
          ]),
          Row(
            children: [
              Switch(
                  value: _crossOver,
                  onChanged: (v) => setState(() => _crossOver = v)),
              const Text('CO', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Switch(
                  value: _knee,
                  onChanged: (v) => setState(() => _knee = v)),
              const Text('Knee', style: TextStyle(fontSize: 12)),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// ── Edit dialog ────────────────────────────────────────────────────────────────

class _EditTrickDialog extends StatefulWidget {
  final TrickDto trick;
  final VoidCallback onSaved;

  const _EditTrickDialog({required this.trick, required this.onSaved});

  @override
  State<_EditTrickDialog> createState() => _EditTrickDialogState();
}

class _EditTrickDialogState extends State<_EditTrickDialog> {
  late final _abbrevCtrl = TextEditingController(text: widget.trick.abbreviation);
  late final _nameCtrl = TextEditingController(text: widget.trick.name);
  late double _revolution = widget.trick.revolution;
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
    setState(() { _loading = true; _error = null; });
    try {
      final updated = TrickDto(
        id: widget.trick.id,
        name: _nameCtrl.text.trim(),
        abbreviation: _abbrevCtrl.text.trim(),
        crossOver: _crossOver,
        knee: _knee,
        revolution: _revolution,
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
              controller: _abbrevCtrl,
              decoration: const InputDecoration(labelText: 'Abbreviation'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _NumField(
                        label: 'Revs',
                        value: _revolution,
                        min: 0.5,
                        max: 10,
                        onChanged: (v) => setState(() => _revolution = v))),
                const SizedBox(width: 8),
                Expanded(
                    child: _NumField(
                        label: 'Difficulty',
                        value: _difficulty.toDouble(),
                        min: 1,
                        max: 10,
                        onChanged: (v) => setState(() => _difficulty = v.round()))),
                const SizedBox(width: 8),
                Expanded(
                    child: _NumField(
                        label: 'Level',
                        value: _commonLevel.toDouble(),
                        min: 1,
                        max: 10,
                        onChanged: (v) => setState(() => _commonLevel = v.round()))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                    value: _crossOver,
                    onChanged: (v) =>
                        setState(() => _crossOver = v ?? false)),
                const Text('CrossOver'),
                const SizedBox(width: 16),
                Checkbox(
                    value: _knee,
                    onChanged: (v) =>
                        setState(() => _knee = v ?? false)),
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
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
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
