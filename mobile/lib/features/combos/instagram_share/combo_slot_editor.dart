import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/combo.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/combo_card.dart' show TrickNameDisplay;
import '../../../widgets/combo_slot_tile.dart';
import '../../../widgets/difficulty_chip.dart';

enum _TypeFilter { all, tricks, combos }

/// Pushes the full-screen trick-list editor and returns the built combo when
/// the user taps Done, or null if they backed out without saving. A full
/// screen — not an inline section — because building/editing a trick list
/// (search, picker, reorderable sequence) needs real room; cramming it into
/// the Share Image sheet alongside the preview and layout/style controls
/// left too little space for either.
///
/// Nothing built here is ever sent to the API — it's purely local state that
/// becomes a synthetic `ComboDto` (blank id/ownerId/createdAt, zeroed
/// ratings) once the user is done, used only to drive the share-image
/// preview/export back on the Share Image sheet.
Future<ComboDto?> showComboSlotEditorScreen(
  BuildContext context, {
  required String initialName,
  required List<SlotItem> initialSlots,
}) {
  return Navigator.of(context).push<ComboDto>(
    MaterialPageRoute(
      builder: (_) => ComboSlotEditorScreen(initialName: initialName, initialSlots: initialSlots),
    ),
  );
}

/// See [showComboSlotEditorScreen] — that's the entry point; this widget is
/// exposed mainly so the route builder above can construct it.
class ComboSlotEditorScreen extends StatefulWidget {
  final String initialName;
  final List<SlotItem> initialSlots;

  const ComboSlotEditorScreen({super.key, required this.initialName, required this.initialSlots});

  @override
  State<ComboSlotEditorScreen> createState() => _ComboSlotEditorScreenState();
}

class _ComboSlotEditorScreenState extends State<ComboSlotEditorScreen> {
  late final TextEditingController _nameCtrl = TextEditingController(text: widget.initialName);
  late final List<SlotItem> _slots = List.of(widget.initialSlots);
  late int _tab = _slots.isEmpty ? 0 : 1; // 0 = Add tricks, 1 = Sequence

  List<TrickListItem> _items = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _search = '';
  _TypeFilter _typeFilter = _TypeFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await ApiClient.instance.getTricks();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // Best-effort — an already-populated (opened-from-combo) editor still
      // lets the user view/reorder/remove its existing slots without a
      // working picker.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Mirrors create_combo_screen.dart's _totalDiff/_totalTrickCount: a plain
  // trick slot's difficulty is looked up live from the loaded trick pool
  // (SlotItem itself doesn't carry difficulty), a sub-combo slot's is summed
  // from its own already-known subComboTricks.
  (int, int) _computeStats() {
    var diff = 0;
    var count = 0;
    for (final s in _slots) {
      if (s.isSubCombo) {
        for (final t in s.subComboTricks ?? const <ComboTrickDto>[]) {
          diff += t.difficulty;
          count++;
        }
      } else {
        final trick = _items.whereType<TrickItem>().where((t) => t.id == s.trickId).firstOrNull;
        if (trick != null) diff += trick.difficulty;
        count++;
      }
    }
    return (diff, count);
  }

  List<ComboTrickDto> _toComboTricks() {
    return _slots.map((s) {
      if (s.isSubCombo) {
        return ComboTrickDto(
          type: 'combo',
          position: s.position,
          subComboId: s.subComboId,
          subComboName: s.subComboName,
          subComboTricks: s.subComboTricks,
          strongFoot: s.strongFoot,
          noTouch: s.noTouch,
        );
      }
      return ComboTrickDto(
        trickId: s.trickId,
        name: s.trickName,
        abbreviation: s.abbreviation,
        position: s.position,
        strongFoot: s.strongFoot,
        noTouch: s.noTouch,
        crossOver: s.crossOver,
        isTransition: s.isTransition,
      );
    }).toList();
  }

  void _done() {
    final (diff, count) = _computeStats();
    final name = _nameCtrl.text.trim();
    Navigator.of(context).pop(ComboDto(
      id: '',
      ownerId: '',
      name: name.isEmpty ? null : name,
      totalDifficulty: diff.toDouble(),
      trickCount: count,
      createdAt: '',
      displayText: _slots.map((s) => s.isSubCombo ? (s.subComboName ?? '') : (s.abbreviation ?? '')).join(' '),
      tricks: _toComboTricks(),
      averageRating: 0,
      totalRatings: 0,
    ));
  }

  void _addTrick(TrickItem trick) {
    setState(() {
      _slots.add(SlotItem.trick(
        trickId: trick.id,
        trickName: trick.name,
        abbreviation: trick.abbreviation,
        crossOver: trick.crossOver,
        position: _slots.length + 1,
        isTransition: trick.isTransition,
      ));
      _tab = 1;
    });
  }

  void _addCombo(ComboItem combo) {
    setState(() {
      _slots.add(SlotItem.combo(
        subComboId: combo.id,
        subComboName: combo.displayName,
        subComboTricks: combo.tricks,
        position: _slots.length + 1,
      ));
      _tab = 1;
    });
  }

  void _removeSlot(int i) {
    setState(() {
      _slots.removeAt(i);
      renumberSlots(_slots);
    });
  }

  void _reorderSlot(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _slots.removeAt(oldIndex);
      _slots.insert(newIndex, item);
      renumberSlots(_slots);
    });
  }

  List<TrickListItem> get _filtered {
    final q = _search.toLowerCase();
    final list = _items.where((item) {
      if (item is TrickItem) {
        if (_typeFilter == _TypeFilter.combos) return false;
        if (q.isEmpty) return true;
        return item.name.toLowerCase().contains(q) || item.abbreviation.toLowerCase().contains(q);
      } else if (item is ComboItem) {
        if (_typeFilter == _TypeFilter.tricks) return false;
        if (q.isEmpty) return true;
        return item.displayName.toLowerCase().contains(q);
      }
      return false;
    }).toList();
    if (q.isEmpty) return list;
    bool isExact(TrickListItem item) {
      if (item is TrickItem) return item.abbreviation.toLowerCase() == q || item.name.toLowerCase() == q;
      if (item is ComboItem) return item.displayName.toLowerCase() == q;
      return false;
    }
    final exact = list.where(isExact).toList();
    final rest = list.where((item) => !isExact(item)).toList();
    return [...exact, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text('Select Tricks', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                autocorrect: false,
                style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Combo name (optional)',
                  hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.faint, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: AppColors.chipBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              _EditorSegmented(
                labels: ['Add tricks', 'Sequence (${_slots.length})'],
                selectedIndex: _tab,
                onSelected: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 14),
              Expanded(child: _tab == 1 ? _buildSlotList() : _buildPicker()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(22, 0, 22, 16),
        child: SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _done,
            child: Text('Done', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotList() {
    if (_slots.isEmpty) {
      return Center(
        child: Text(
          'No tricks selected yet.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
      );
    }
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _slots.length,
      onReorder: _reorderSlot,
      itemBuilder: (_, i) {
        final s = _slots[i];
        if (s.isSubCombo) {
          return SubComboSlotTile(
            key: ObjectKey(s),
            index: i,
            slot: s,
            onRemove: () => _removeSlot(i),
            onToggleExpand: () => setState(() => s.expanded = !s.expanded),
          );
        }
        final noTouchAllowed = i > 0 && _slots[i - 1].allowsNoTouchOnNext;
        return SlotTile(
          key: ObjectKey(s),
          index: i,
          slot: s,
          showAbbrev: !TrickNameDisplay.showFullName,
          noTouchAllowed: noTouchAllowed,
          onRemove: () => _removeSlot(i),
          onToggleStrongFoot: (v) => setState(() => s.strongFoot = v),
          onToggleNoTouch: (v) => setState(() => s.noTouch = v),
        );
      },
    );
  }

  Widget _buildPicker() {
    final filtered = _filtered;
    final pinned = filtered.whereType<TrickItem>().where((t) => t.isTransition).toList();
    final rest = filtered.where((item) => !(item is TrickItem && item.isTransition)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          autocorrect: false,
          enableSuggestions: false,
          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Search…',
            hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.faint, fontWeight: FontWeight.w600),
            prefixIcon: const Icon(Icons.search, color: AppColors.faint),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.faint),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                  )
                : null,
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _typeChip(_TypeFilter.all, 'All'),
            const SizedBox(width: 6),
            _typeChip(_TypeFilter.tricks, 'Tricks'),
            const SizedBox(width: 6),
            _typeChip(_TypeFilter.combos, 'Combos'),
          ],
        ),
        const SizedBox(height: 10),
        if (pinned.isNotEmpty) ...pinned.map((t) => _PickerRow.trick(item: t, onAdd: () => _addTrick(t))),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.indigo))
              : rest.isEmpty
                  ? Center(
                      child: Text(
                        _search.trim().isEmpty ? 'No tricks found.' : 'No tricks found for "${_search.trim()}".',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: rest.length,
                      itemBuilder: (_, i) {
                        final item = rest[i];
                        if (item is TrickItem) return _PickerRow.trick(item: item, onAdd: () => _addTrick(item));
                        if (item is ComboItem) return _PickerRow.combo(item: item, onAdd: () => _addCombo(item));
                        return const SizedBox.shrink();
                      },
                    ),
        ),
      ],
    );
  }

  Widget _typeChip(_TypeFilter type, String label) {
    final active = _typeFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _typeFilter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.indigo : AppColors.chipBg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.ink2),
        ),
      ),
    );
  }
}

class _EditorSegmented extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _EditorSegmented({required this.labels, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selectedIndex == i ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: selectedIndex == i ? [BoxShadow(color: AppColors.ink.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 1))] : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: selectedIndex == i ? AppColors.indigo : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final TrickItem? trick;
  final ComboItem? combo;
  final VoidCallback onAdd;

  const _PickerRow.trick({required TrickItem item, required this.onAdd})
      : trick = item,
        combo = null;

  const _PickerRow.combo({required ComboItem item, required this.onAdd})
      : trick = null,
        combo = item;

  @override
  Widget build(BuildContext context) {
    final t = trick;
    final c = combo;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: t != null ? AppColors.surface : const Color(0xFFF7F5FE),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(color: t != null ? AppColors.line : const Color(0xFFE5E0FB)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                if (t != null)
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      t.abbreviation,
                      style: GoogleFonts.jetBrainsMono(fontSize: 8.5, height: 1.15, fontWeight: FontWeight.w800, color: AppColors.indigo),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.layers, size: 18, color: AppColors.noTouchText),
                  ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (t != null)
                        Text(
                          TrickNameDisplay.label(isTransition: t.isTransition, name: t.name, abbreviation: t.abbreviation),
                          style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c!.displayName,
                                style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(6)),
                              child: Text('COMBO', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.noTouchText)),
                            ),
                          ],
                        ),
                      const SizedBox(height: 2),
                      Text(
                        t != null ? '${t.revolution} rev${t.crossOver ? ' · crossover' : ''}${t.knee ? ' · knee' : ''}' : '${c!.trickCount} tricks',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DifficultyChip(t != null ? t.difficulty : c!.totalDifficulty.toInt()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
