import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/models/combo.dart';

class BuildComboScreen extends StatefulWidget {
  const BuildComboScreen({super.key});

  @override
  State<BuildComboScreen> createState() => _BuildComboScreenState();
}

class _SlotItem {
  final String trickId;
  final String trickName;
  final String abbreviation;
  final bool crossOver;
  int position;
  bool strongFoot;
  bool noTouch;

  _SlotItem({
    required this.trickId,
    required this.trickName,
    required this.abbreviation,
    required this.crossOver,
    required this.position,
    this.strongFoot = true,
    this.noTouch = false,
  });
}

class _BuildComboScreenState extends State<BuildComboScreen> {
  List<TrickDto> _tricks = [];
  bool _loadingTricks = true;
  final _searchCtrl = TextEditingController();
  String _search = '';

  final List<_SlotItem> _slots = [];
  bool _isPublic = false;
  bool _saving = false;
  String? _error;
  ComboDto? _result;
  final _nameCtrl = TextEditingController();

  int _tab = 0; // 0 = pick tricks, 1 = my combo

  @override
  void initState() {
    super.initState();
    _loadTricks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTricks() async {
    try {
      final tricks = await ApiClient.instance.getTricks();
      if (mounted) setState(() => _tricks = tricks);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingTricks = false);
    }
  }

  void _addTrick(TrickDto trick) {
    setState(() {
      _slots.add(_SlotItem(
        trickId: trick.id,
        trickName: trick.name,
        abbreviation: trick.abbreviation,
        crossOver: trick.crossOver,
        position: _slots.length + 1,
      ));
      _tab = 1;
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index);
      for (var i = 0; i < _slots.length; i++) {
        _slots[i].position = i + 1;
      }
    });
  }

  Future<void> _save() async {
    if (_slots.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final items = _slots
          .map((s) => BuildComboTrickItem(
                trickId: s.trickId,
                position: s.position,
                strongFoot: s.strongFoot,
                noTouch: s.noTouch,
              ))
          .toList();
      final name = _nameCtrl.text.trim();
      final combo = await ApiClient.instance.buildCombo(
        items,
        _isPublic,
        name: name.isEmpty ? null : name,
      );
      setState(() => _result = combo);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  double get _avgDiff {
    if (_slots.isEmpty) return 0;
    final total = _slots.fold<double>(0, (sum, s) {
      final trick = _tricks.firstWhere((t) => t.id == s.trickId,
          orElse: () => TrickDto(
                id: '',
                name: '',
                abbreviation: '',
                crossOver: false,
                knee: false,
                motion: 0,
                difficulty: 0,
                commonLevel: 0,
              ));
      return sum + trick.difficulty;
    });
    return total / _slots.length;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Build Combo'),
          bottom: TabBar(
            onTap: (i) => setState(() => _tab = i),
            tabs: [
              Tab(text: 'Tricks (${_tricks.length})'),
              Tab(text: 'My Combo (${_slots.length})'),
            ],
          ),
        ),
        body: IndexedStack(
          index: _tab,
          children: [
            _buildPickerTab(),
            _buildComboTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search…',
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
        Expanded(
          child: _loadingTricks
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = _filtered[i];
                    return ListTile(
                      title: Text(t.name),
                      subtitle: Text(
                        t.abbreviation,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (t.crossOver)
                            const _MiniTag(label: 'CO'),
                          if (t.knee)
                            const _MiniTag(label: 'K'),
                          const SizedBox(width: 4),
                          _DiffChip(difficulty: t.difficulty),
                          const SizedBox(width: 4),
                          const Icon(Icons.add_circle_outline, color: Colors.indigo),
                        ],
                      ),
                      onTap: () => _addTrick(t),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildComboTab() {
    if (_result != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved!', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_result!.displayText,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${_result!.trickCount} tricks · avg diff ${_result!.averageDifficulty.toStringAsFixed(1)}'),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('View combo'),
              onPressed: () => context.push('/combos/${_result!.id}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() {
                _result = null;
                _slots.clear();
                _tab = 0;
              }),
              child: const Text('Build another'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_slots.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'Add tricks from the first tab.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              itemCount: _slots.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _slots[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text('${s.position}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.trickName,
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(s.abbreviation,
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      _Toggle(
                        label: 'SF',
                        value: s.strongFoot,
                        onChanged: (v) => setState(() => s.strongFoot = v),
                      ),
                      _Toggle(
                        label: 'NT',
                        value: s.noTouch,
                        enabled: s.crossOver,
                        onChanged: s.crossOver
                            ? (v) => setState(() => s.noTouch = v)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                        onPressed: () => _removeSlot(i),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (_slots.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_slots.length} tricks · avg diff ${_avgDiff.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Combo name (optional)',
                    hintText: 'e.g. My signature combo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v ?? false),
                    ),
                    const Text('Make public'),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Combo'),
                ),
              ],
            ),
          ),
        ],
      ],
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

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _Toggle({
    required this.label,
    required this.value,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: enabled ? Colors.grey[700] : Colors.grey[400],
          ),
        ),
        Checkbox(
          value: value,
          onChanged: enabled ? (v) => onChanged?.call(v ?? false) : null,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}
