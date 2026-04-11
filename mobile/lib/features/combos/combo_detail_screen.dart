import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';
import '../../widgets/rate_combo_dialog.dart';

class _SlotItem {
  final String trickId;
  final String trickName;
  final String abbreviation;
  bool crossOver;
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

  Future<void> _openEdit(ComboDto combo) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditComboScreen(combo: combo),
        fullscreenDialog: true,
      ),
    );
    if (updated == true) _load();
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
                    if (combo.ownerUserName != null)
                      Text('by ${combo.ownerUserName}',
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
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!isOwner && currentUserId != null)
                      OutlinedButton.icon(
                        onPressed: () => _openRating(combo.id),
                        icon: const Icon(Icons.star_outline),
                        label: const Text('Rate this combo'),
                      ),
                    if (isOwner)
                      OutlinedButton.icon(
                        onPressed: () => _openEdit(combo),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit combo'),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Edit Combo Screen ──────────────────────────────────────────────────────────

class _EditComboScreen extends StatefulWidget {
  final ComboDto combo;
  const _EditComboScreen({required this.combo});

  @override
  State<_EditComboScreen> createState() => _EditComboScreenState();
}

class _EditComboScreenState extends State<_EditComboScreen> {
  late final TextEditingController _nameCtrl;
  late final List<_SlotItem> _slots;
  List<TrickDto> _tricks = [];
  bool _loadingTricks = true;
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _saving = false;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.combo.name ?? '');
    _slots = (widget.combo.tricks ?? []).map((t) => _SlotItem(
      trickId: t.trickId,
      trickName: t.name,
      abbreviation: t.abbreviation,
      crossOver: false, // will be updated when tricks load
      position: t.position,
      strongFoot: t.strongFoot,
      noTouch: t.noTouch,
    )).toList();
    _loadTricks();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTricks() async {
    try {
      final tricks = await ApiClient.instance.getTricks();
      if (mounted) {
        final trickMap = {for (final t in tricks) t.id: t};
        for (final slot in _slots) {
          final trick = trickMap[slot.trickId];
          if (trick != null) slot.crossOver = trick.crossOver;
        }
        setState(() => _tricks = tricks);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingTricks = false);
    }
  }

  List<TrickDto> get _filtered {
    final q = _search.toLowerCase();
    if (q.isEmpty) return _tricks;
    return _tricks.where((t) => t.name.toLowerCase().contains(q) || t.abbreviation.toLowerCase().contains(q)).toList();
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
      for (var i = 0; i < _slots.length; i++) _slots[i].position = i + 1;
    });
  }

  Future<void> _save() async {
    if (_slots.isEmpty) return;
    setState(() { _saving = true; _error = null; });
    try {
      final name = _nameCtrl.text.trim();
      final tricks = _slots.map((s) => BuildComboTrickItem(
        trickId: s.trickId,
        position: s.position,
        strongFoot: s.strongFoot,
        noTouch: s.noTouch,
      )).toList();
      await ApiClient.instance.updateCombo(
        widget.combo.id,
        name: name,
        tricks: tricks,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Combo'),
        actions: [
          TextButton(
            onPressed: _saving || _slots.isEmpty ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Combo name (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    onTap: (i) => setState(() => _tab = i),
                    tabs: [
                      Tab(text: 'Tricks (${_tricks.length})'),
                      Tab(text: 'Combo (${_slots.length})'),
                    ],
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _tab,
                      children: [_pickerTab(), _comboTab()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerTab() {
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
              isDense: true,
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
                      dense: true,
                      title: Text(t.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(t.abbreviation, style: const TextStyle(fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (t.crossOver) _Tag('CO'),
                          if (t.knee) _Tag('K'),
                          const SizedBox(width: 4),
                          const Icon(Icons.add_circle_outline, color: Colors.indigo, size: 20),
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

  Widget _comboTab() {
    if (_slots.isEmpty) {
      return const Center(child: Text('No tricks. Add from the Tricks tab.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
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
                Text(s.trickName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Text(s.abbreviation, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
              _ToggleCheck(
                label: 'SF',
                value: s.strongFoot,
                onChanged: (v) => setState(() => s.strongFoot = v),
              ),
              _ToggleCheck(
                label: 'NT',
                value: s.noTouch,
                enabled: s.crossOver,
                onChanged: s.crossOver ? (v) => setState(() => s.noTouch = v) : null,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _removeSlot(i),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _ToggleCheck extends StatelessWidget {
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _ToggleCheck({required this.label, required this.value, this.enabled = true, this.onChanged});

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
