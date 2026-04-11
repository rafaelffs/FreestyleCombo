import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/models/combo.dart';
import '../../widgets/combo_card.dart';

enum _Mode { choose, generate, build }

class CreateComboScreen extends StatefulWidget {
  const CreateComboScreen({super.key});

  @override
  State<CreateComboScreen> createState() => _CreateComboScreenState();
}

// ── Slot item for build mode ────────────────────────────────────────────────

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

class _CreateComboScreenState extends State<CreateComboScreen> {
  _Mode _mode = _Mode.choose;

  // ── Generate state ─────────────────────────────────────────────────────────
  bool _usePrefs = false;
  int _comboLength = 5;
  int _maxDifficulty = 10;
  int _strongFootPct = 50;
  int _noTouchPct = 30;
  int _maxConsecNoTouch = 2;
  bool _includeCrossOver = true;
  bool _includeKnee = true;
  final _genNameCtrl = TextEditingController();
  bool _genLoading = false;
  String? _genError;
  ComboDto? _genResult;

  // ── Build state ────────────────────────────────────────────────────────────
  List<TrickDto> _tricks = [];
  bool _loadingTricks = true;
  final _searchCtrl = TextEditingController();
  String _search = '';
  final List<_SlotItem> _slots = [];
  bool _isPublic = false;
  bool _saving = false;
  String? _buildError;
  ComboDto? _buildResult;
  final _buildNameCtrl = TextEditingController();
  int _buildTab = 0;

  @override
  void dispose() {
    _genNameCtrl.dispose();
    _searchCtrl.dispose();
    _buildNameCtrl.dispose();
    super.dispose();
  }

  // ── Generate actions ────────────────────────────────────────────────────────

  Future<void> _generate() async {
    setState(() { _genLoading = true; _genError = null; _genResult = null; });
    try {
      final overrides = _usePrefs
          ? null
          : GenerateComboOverrides(
              comboLength: _comboLength,
              maxDifficulty: _maxDifficulty,
              strongFootPercentage: _strongFootPct,
              noTouchPercentage: _noTouchPct,
              maxConsecutiveNoTouch: _maxConsecNoTouch,
              includeCrossOver: _includeCrossOver,
              includeKnee: _includeKnee,
            );
      final name = _genNameCtrl.text.trim();
      final combo = await ApiClient.instance.generateCombo(
        _usePrefs,
        overrides,
        name: name.isEmpty ? null : name,
      );
      setState(() => _genResult = combo);
    } catch (e) {
      setState(() => _genError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _genLoading = false);
    }
  }

  // ── Build actions ────────────────────────────────────────────────────────────

  Future<void> _loadTricks() async {
    setState(() => _loadingTricks = true);
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
      _buildTab = 1;
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index);
      for (var i = 0; i < _slots.length; i++) _slots[i].position = i + 1;
    });
  }

  Future<void> _save() async {
    if (_slots.isEmpty) return;
    setState(() { _saving = true; _buildError = null; });
    try {
      final items = _slots
          .map((s) => BuildComboTrickItem(trickId: s.trickId, position: s.position, strongFoot: s.strongFoot, noTouch: s.noTouch))
          .toList();
      final name = _buildNameCtrl.text.trim();
      final combo = await ApiClient.instance.buildCombo(items, _isPublic, name: name.isEmpty ? null : name);
      setState(() => _buildResult = combo);
    } catch (e) {
      setState(() => _buildError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<TrickDto> get _filtered {
    final q = _search.toLowerCase();
    if (q.isEmpty) return _tricks;
    return _tricks.where((t) => t.name.toLowerCase().contains(q) || t.abbreviation.toLowerCase().contains(q)).toList();
  }

  double get _avgDiff {
    if (_slots.isEmpty) return 0;
    final total = _slots.fold<double>(0, (sum, s) {
      final trick = _tricks.firstWhere((t) => t.id == s.trickId,
          orElse: () => TrickDto(id: '', name: '', abbreviation: '', crossOver: false, knee: false, motion: 0, difficulty: 0, commonLevel: 0));
      return sum + trick.difficulty;
    });
    return total / _slots.length;
  }

  // ── Mode switching ────────────────────────────────────────────────────────────

  void _switchMode(_Mode mode) {
    setState(() => _mode = mode);
    if (mode == _Mode.build && _tricks.isEmpty) _loadTricks();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _mode == _Mode.choose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _mode != _Mode.choose) setState(() => _mode = _Mode.choose);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Combo'),
          leading: _mode != _Mode.choose
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _mode = _Mode.choose),
                )
              : null,
        ),
        body: _mode == _Mode.choose
            ? _buildChooseView()
            : _mode == _Mode.generate
                ? _buildGenerateView()
                : _buildBuildView(),
      ),
    );
  }

  // ── Choose view ────────────────────────────────────────────────────────────────

  Widget _buildChooseView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How would you like to create your combo?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          _ModeCard(
            icon: Icons.auto_awesome,
            title: 'Auto-generate',
            description: 'Let the app build a combo based on your settings.',
            onTap: () => _switchMode(_Mode.generate),
          ),
          const SizedBox(height: 16),
          _ModeCard(
            icon: Icons.build_outlined,
            title: 'Build manually',
            description: 'Pick tricks one by one and configure each slot.',
            onTap: () => _switchMode(_Mode.build),
          ),
        ],
      ),
    );
  }

  // ── Generate view ────────────────────────────────────────────────────────────

  Widget _buildGenerateView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Options', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _genNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Combo name (optional)',
                      hintText: 'e.g. My signature combo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Use saved preferences'),
                    value: _usePrefs,
                    onChanged: (v) => setState(() => _usePrefs = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!_usePrefs) ...[
                    const Divider(),
                    _SliderRow(label: 'Combo length: $_comboLength', value: _comboLength.toDouble(), min: 1, max: 100, divisions: 99, onChanged: (v) => setState(() => _comboLength = v.round())),
                    _SliderRow(label: 'Max difficulty: $_maxDifficulty', value: _maxDifficulty.toDouble(), min: 1, max: 10, divisions: 9, onChanged: (v) => setState(() => _maxDifficulty = v.round())),
                    _SliderRow(label: 'Strong foot: $_strongFootPct%', value: _strongFootPct.toDouble(), min: 0, max: 100, divisions: 10, onChanged: (v) => setState(() => _strongFootPct = v.round())),
                    _SliderRow(label: 'No-touch: $_noTouchPct%', value: _noTouchPct.toDouble(), min: 0, max: 100, divisions: 10, onChanged: (v) => setState(() => _noTouchPct = v.round())),
                    _SliderRow(label: 'Max consecutive NT: $_maxConsecNoTouch', value: _maxConsecNoTouch.toDouble(), min: 0, max: 30, divisions: 30, onChanged: (v) => setState(() => _maxConsecNoTouch = v.round())),
                    SwitchListTile(title: const Text('Include crossover'), value: _includeCrossOver, onChanged: (v) => setState(() => _includeCrossOver = v), contentPadding: EdgeInsets.zero),
                    SwitchListTile(title: const Text('Include knee'), value: _includeKnee, onChanged: (v) => setState(() => _includeKnee = v), contentPadding: EdgeInsets.zero),
                  ],
                ],
              ),
            ),
          ),
          if (_genError != null) ...[
            const SizedBox(height: 12),
            Text(_genError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _genLoading ? null : _generate,
            icon: _genLoading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_genLoading ? 'Generating…' : 'Generate Combo'),
          ),
          if (_genResult != null) ...[
            const SizedBox(height: 24),
            Text('Result', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ComboCard(combo: _genResult!, showActions: true),
          ],
        ],
      ),
    );
  }

  // ── Build view ────────────────────────────────────────────────────────────────

  Widget _buildBuildView() {
    if (_buildResult != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved!', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_buildResult!.displayText, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${_buildResult!.trickCount} tricks · avg diff ${_buildResult!.averageDifficulty.toStringAsFixed(1)}'),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('View combo'),
              onPressed: () => context.push('/combos/${_buildResult!.id}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() { _buildResult = null; _slots.clear(); _buildTab = 0; }),
              child: const Text('Build another'),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            onTap: (i) => setState(() => _buildTab = i),
            tabs: [
              Tab(text: 'Tricks (${_tricks.length})'),
              Tab(text: 'My Combo (${_slots.length})'),
            ],
          ),
          Expanded(
            child: IndexedStack(
              index: _buildTab,
              children: [
                _buildPickerTab(),
                _buildComboTab(),
              ],
            ),
          ),
        ],
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
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
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
                      subtitle: Text(t.abbreviation, style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (t.crossOver) const _MiniTag(label: 'CO'),
                          if (t.knee) const _MiniTag(label: 'K'),
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
    return Column(
      children: [
        if (_slots.isEmpty)
          const Expanded(child: Center(child: Text('Add tricks from the first tab.', style: TextStyle(color: Colors.grey))))
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
                      SizedBox(width: 20, child: Text('${s.position}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.trickName, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(s.abbreviation, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ])),
                      _Toggle(label: 'SF', value: s.strongFoot, onChanged: (v) => setState(() => s.strongFoot = v)),
                      _Toggle(label: 'NT', value: s.noTouch, enabled: s.crossOver, onChanged: s.crossOver ? (v) => setState(() => s.noTouch = v) : null),
                      IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: () => _removeSlot(i)),
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
                Text('${_slots.length} tricks · avg diff ${_avgDiff.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextField(
                  controller: _buildNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Combo name (optional)',
                    hintText: 'e.g. My signature combo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Checkbox(value: _isPublic, onChanged: (v) => setState(() => _isPublic = v ?? false)),
                  const Text('Make public'),
                ]),
                if (_buildError != null) ...[
                  const SizedBox(height: 4),
                  Text(_buildError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ModeCard({required this.icon, required this.title, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.indigo, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
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
    if (difficulty <= 4) { bg = Colors.green.shade100; fg = Colors.green.shade800; }
    else if (difficulty <= 7) { bg = Colors.yellow.shade100; fg = Colors.yellow.shade900; }
    else { bg = Colors.red.shade100; fg = Colors.red.shade800; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text('$difficulty', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
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
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _Toggle({required this.label, required this.value, this.enabled = true, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: enabled ? Colors.grey[700] : Colors.grey[400])),
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

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({required this.label, required this.value, required this.min, required this.max, this.divisions, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
      ],
    );
  }
}
