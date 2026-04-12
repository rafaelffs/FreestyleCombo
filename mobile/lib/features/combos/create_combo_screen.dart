import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/models/combo.dart';
import '../../core/models/user_preference.dart';
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

  // ── Shared name field ──────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();

  // ── Generate state ─────────────────────────────────────────────────────────
  List<UserPreference> _savedPrefs = [];
  String? _selectedPrefId; // null = Custom
  int _comboLength = 5;
  int _maxDifficulty = 10;
  int _strongFootPct = 50;
  int _noTouchPct = 30;
  int _maxConsecNoTouch = 2;
  bool _includeCrossOver = true;
  bool _includeKnee = true;
  bool _genLoading = false;
  String? _genError;
  List<String> _previewWarnings = [];

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
  int _buildTab = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Generate actions ────────────────────────────────────────────────────────

  Future<void> _loadPreferences() async {
    try {
      final prefs = await ApiClient.instance.getPreferences();
      if (mounted) setState(() => _savedPrefs = prefs);
    } catch (_) {
      // Non-critical — user can still generate with custom settings
    }
  }

  Future<void> _preview() async {
    setState(() { _genLoading = true; _genError = null; });
    try {
      final overrides = _selectedPrefId != null
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
      final result = await ApiClient.instance.previewCombo(_selectedPrefId, overrides);
      _slots.clear();
      for (final t in result.tricks) {
        _slots.add(_SlotItem(
          trickId: t.trickId,
          trickName: t.trickName,
          abbreviation: t.abbreviation,
          crossOver: t.crossOver,
          position: t.position,
          strongFoot: t.strongFoot,
          noTouch: t.noTouch,
        ));
      }
      setState(() {
        _previewWarnings = result.warnings;
        _mode = _Mode.build;
        _buildTab = 1;
      });
      if (_tricks.isEmpty) _loadTricks();
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
      final name = _nameCtrl.text.trim();
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
          orElse: () => TrickDto(id: '', name: '', abbreviation: '', crossOver: false, knee: false, revolution: 0, difficulty: 0, commonLevel: 0));
      return sum + trick.difficulty;
    });
    return total / _slots.length;
  }

  // ── Mode switching ────────────────────────────────────────────────────────────

  void _switchToBuild() {
    setState(() => _mode = _Mode.build);
    if (_tricks.isEmpty) _loadTricks();
  }

  void _backToChoose() {
    setState(() {
      _mode = _Mode.choose;
      _slots.clear();
      _previewWarnings = [];
      _buildResult = null;
      _buildTab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _mode == _Mode.choose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _mode != _Mode.choose) _backToChoose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Combo'),
          leading: _mode != _Mode.choose
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _backToChoose,
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
            onTap: () {
              setState(() => _mode = _Mode.generate);
              _loadPreferences();
            },
          ),
          const SizedBox(height: 16),
          _ModeCard(
            icon: Icons.build_outlined,
            title: 'Build manually',
            description: 'Pick tricks one by one and configure each slot.',
            onTap: _switchToBuild,
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
          // Name field at the top
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Combo name (optional)',
              hintText: 'e.g. My signature combo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Options', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  // Preference selector
                  DropdownButtonFormField<String?>(
                    value: _selectedPrefId,
                    decoration: const InputDecoration(
                      labelText: 'Preference',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Custom')),
                      ..._savedPrefs.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedPrefId = v;
                        // When a preference is selected, copy its values for display
                        final pref = v != null ? _savedPrefs.firstWhere((p) => p.id == v) : null;
                        if (pref != null) {
                          _comboLength = pref.comboLength;
                          _maxDifficulty = pref.maxDifficulty;
                          _strongFootPct = pref.strongFootPercentage;
                          _noTouchPct = pref.noTouchPercentage;
                          _maxConsecNoTouch = pref.maxConsecutiveNoTouch;
                          _includeCrossOver = pref.includeCrossOver;
                          _includeKnee = pref.includeKnee;
                        }
                      });
                    },
                  ),
                  const Divider(),
                  _SliderRow(label: 'Combo length: $_comboLength', value: _comboLength.toDouble(), min: 1, max: 100, divisions: 99, onChanged: _selectedPrefId == null ? (v) => setState(() => _comboLength = v.round()) : null),
                  _SliderRow(label: 'Max difficulty: $_maxDifficulty', value: _maxDifficulty.toDouble(), min: 1, max: 10, divisions: 9, onChanged: _selectedPrefId == null ? (v) => setState(() => _maxDifficulty = v.round()) : null),
                  _SliderRow(label: 'Strong foot: $_strongFootPct%', value: _strongFootPct.toDouble(), min: 0, max: 100, divisions: 10, onChanged: _selectedPrefId == null ? (v) => setState(() => _strongFootPct = v.round()) : null),
                  _SliderRow(label: 'No-touch: $_noTouchPct%', value: _noTouchPct.toDouble(), min: 0, max: 100, divisions: 10, onChanged: _selectedPrefId == null ? (v) => setState(() => _noTouchPct = v.round()) : null),
                  _SliderRow(label: 'Max consecutive NT: $_maxConsecNoTouch', value: _maxConsecNoTouch.toDouble(), min: 0, max: 30, divisions: 30, onChanged: _selectedPrefId == null ? (v) => setState(() => _maxConsecNoTouch = v.round()) : null),
                  SwitchListTile(title: const Text('Include crossover'), value: _includeCrossOver, onChanged: _selectedPrefId == null ? (v) => setState(() => _includeCrossOver = v) : null, contentPadding: EdgeInsets.zero),
                  SwitchListTile(title: const Text('Include knee'), value: _includeKnee, onChanged: _selectedPrefId == null ? (v) => setState(() => _includeKnee = v) : null, contentPadding: EdgeInsets.zero),
                  if (_selectedPrefId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Fields are locked to the selected preference. Choose "Custom" to edit.', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ),
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
            onPressed: _genLoading ? null : _preview,
            icon: _genLoading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_genLoading ? 'Generating…' : 'Generate Combo'),
          ),
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
              onPressed: () => setState(() { _buildResult = null; _slots.clear(); _buildTab = 0; _previewWarnings = []; }),
              child: const Text('Build another'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Name field at the top
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Combo name (optional)',
              hintText: 'e.g. My signature combo',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        if (_previewWarnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _previewWarnings.map((w) => Text(w, style: TextStyle(fontSize: 12, color: Colors.amber.shade900))).toList(),
              ),
            ),
          ),
        Expanded(
          child: DefaultTabController(
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
          ),
        ),
      ],
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
                      title: Row(
                        children: [
                          Text(t.abbreviation, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t.name, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.normal), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
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
  final ValueChanged<double>? onChanged;

  const _SliderRow({required this.label, required this.value, required this.min, required this.max, this.divisions, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: onChanged == null ? Colors.grey : null)),
        Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
      ],
    );
  }
}
