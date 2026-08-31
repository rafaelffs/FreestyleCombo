import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';
import '../../theme/app_colors.dart';
import '../../widgets/combo_card.dart' show TrickNameDisplay;
import '../../widgets/difficulty_chip.dart';
import '../../widgets/submit_trick_sheet.dart';

enum _SortKey { abbreviation, name, revolution, difficulty }

enum _TypeFilter { all, tricks, combos }

class TricksScreen extends StatefulWidget {
  const TricksScreen({super.key});

  @override
  State<TricksScreen> createState() => _TricksScreenState();
}

class _TricksScreenState extends State<TricksScreen> {
  List<TrickListItem> _items = [];
  bool _loading = true;
  String? _error;

  // Expanded combo IDs
  final Set<String> _expandedCombos = {};

  // Filters
  final _searchCtrl = TextEditingController();
  String _search = '';
  int? _minDiff;
  int? _maxDiff;
  Set<double> _selectedRevs = {};
  _TypeFilter _typeFilter = _TypeFilter.all;

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
      final items = await ApiClient.instance.getTricks();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTrick(TrickItem trick) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete trick?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: Text(
          'Delete "${trick.name}"? This will fail if used in any combo.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.ink2, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
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

  Future<void> _removeReusable(ComboItem combo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove reusable flag?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: Text(
          'Remove "${combo.name}" from the reusable combos list?',
          style: GoogleFonts.plusJakartaSans(color: AppColors.ink2, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.setComboReusable(combo.id, false);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _openSubmit({String? initialName}) {
    showSubmitTrickSheet(
      context,
      initialName: initialName,
      onSubmitted: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trick submitted for review!')),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _search.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasSearch ? 'No tricks found for "${_search.trim()}".' : 'No tricks found.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 6),
              Text(
                'Missing a trick?',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: AppColors.ink2, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _openSubmit(initialName: _search.trim()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.grad,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'Submit "${_search.trim()}"',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openEdit(TrickItem trick) {
    showDialog<void>(
      context: context,
      builder: (_) => _EditTrickDialog(trick: trick, onSaved: _load),
    );
  }

  List<double> get _revOptions {
    final revs = _items
        .whereType<TrickItem>()
        .map((t) => t.revolution)
        .toSet()
        .toList()
      ..sort();
    return revs;
  }

  void _showRevFilter() {
    final revOptions = _revOptions;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 14, 8),
                child: Row(
                  children: [
                    Text(
                      'Filter by revolutions',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const Spacer(),
                    if (_selectedRevs.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedRevs = {});
                          setSt(() {});
                        },
                        child: Text('Clear', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.indigo)),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  children: revOptions.map((rev) {
                    final selected = _selectedRevs.contains(rev);
                    return _RevOption(
                      label: '${rev % 1 == 0 ? rev.toInt() : rev} rev${rev == 1 ? '' : 's'}',
                      selected: selected,
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedRevs = _selectedRevs.where((r) => r != rev).toSet();
                          } else {
                            _selectedRevs = {..._selectedRevs, rev};
                          }
                        });
                        setSt(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.indigo,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TrickListItem> get _filtered {
    final q = _search.toLowerCase();
    var list = _items.where((item) {
      if (item is TrickItem) {
        if (_typeFilter == _TypeFilter.combos) return false;
        if (q.isNotEmpty &&
            !item.name.toLowerCase().contains(q) &&
            !item.abbreviation.toLowerCase().contains(q)) return false;
        if (_minDiff != null && item.difficulty < _minDiff!) return false;
        if (_maxDiff != null && item.difficulty > _maxDiff!) return false;
        if (_selectedRevs.isNotEmpty && !_selectedRevs.contains(item.revolution)) return false;
        return true;
      } else if (item is ComboItem) {
        if (_typeFilter == _TypeFilter.tricks) return false;
        // Combos: only filter by search on name, ignore diff/rev filters
        if (q.isNotEmpty && !item.name.toLowerCase().contains(q)) return false;
        return true;
      }
      return true;
    }).toList();

    // Sort: combos always go after tricks, tricks sorted per user choice
    final tricks = list.whereType<TrickItem>().toList();
    final combos = list.whereType<ComboItem>().toList();

    tricks.sort((a, b) {
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

    combos.sort((a, b) => a.name.compareTo(b.name));

    return [...tricks, ...combos];
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

  static const _sortLabels = {
    _SortKey.abbreviation: 'Abbrev',
    _SortKey.name: 'Name',
    _SortKey.difficulty: 'Diff',
    _SortKey.revolution: 'Revs',
  };

  void _showSortSheet() {
    final revOptions = _revOptions;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                  child: Text(
                    'Sort by',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                  child: Column(
                    children: _sortLabels.entries.map((e) {
                      final selected = _sortKey == e.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              _setSort(e.key);
                              setSt(() {});
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.indigoTint : AppColors.surface,
                                border: Border.all(color: selected ? const Color(0xFFC7CCF7) : AppColors.line),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.value,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: selected ? AppColors.indigo : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 18, color: AppColors.indigo)
                                  else
                                    const Icon(Icons.circle_outlined, size: 20, color: AppColors.faint),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 14, 8),
                  child: Row(
                    children: [
                      Text(
                        'Filter by revolutions',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                      const Spacer(),
                      if (_selectedRevs.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedRevs = {});
                            setSt(() {});
                          },
                          child: Text('Clear', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.indigo)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                  child: Column(
                    children: revOptions.map((rev) {
                      final selected = _selectedRevs.contains(rev);
                      return _RevOption(
                        label: '${rev % 1 == 0 ? rev.toInt() : rev} rev${rev == 1 ? '' : 's'}',
                        selected: selected,
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedRevs = _selectedRevs.where((r) => r != rev).toSet();
                            } else {
                              _selectedRevs = {..._selectedRevs, rev};
                            }
                          });
                          setSt(() {});
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeChip(_TypeFilter type, String label) {
    final active = _typeFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _typeFilter = type),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.indigo : AppColors.chipBg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }

  Widget _nameFormatChip(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => TrickNameDisplay.showFullName = label == 'Name'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.indigo : AppColors.chipBg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }

  Widget _buildTrickTile(TrickItem t, bool admin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
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
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TrickNameDisplay.label(isTransition: t.isTransition, name: t.name, abbreviation: t.abbreviation),
                  style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${t.revolution % 1 == 0 ? t.revolution.toInt() : t.revolution} rev',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                    if (t.crossOver) ...[
                      Text(' · ', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted)),
                      Text('crossover', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    ],
                    if (t.knee) ...[
                      Text(' · ', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted)),
                      Text('knee', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DifficultyChip(t.difficulty),
          if (admin) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _openEdit(t),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _deleteTrick(t),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComboTile(ComboItem c, bool admin) {
    final expanded = _expandedCombos.contains(c.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FE),
        border: Border.all(color: const Color(0xFFE5E0FB)),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedCombos.remove(c.id);
                } else {
                  _expandedCombos.add(c.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              child: Row(
                children: [
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.name,
                                style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                'COMBO',
                                style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.noTouchText),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${c.trickCount} tricks',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DifficultyChip(c.totalDifficulty.toInt()),
                  if (admin)
                    IconButton(
                      icon: const Icon(Icons.link_off, size: 18, color: AppColors.red),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Remove reusable',
                      onPressed: () => _removeReusable(c),
                    ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.noTouchText,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 13),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: c.tricks.map((t) {
                  final suffix = t.noTouch ? '·nt' : (!t.strongFoot ? '·wf' : '');
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9)),
                    child: Text(
                      '${t.position}. ${t.abbreviation ?? ''}$suffix',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink2),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
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

    final comboCount = _items.whereType<ComboItem>().length;
    final trickCount = _items.whereType<TrickItem>().length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        titleSpacing: 22,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tricks'),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$trickCount tricks · $comboCount combos',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: authed ? 8 : 22),
            child: _CircleIconButton(icon: Icons.refresh, onTap: _load),
          ),
          if (authed)
            Padding(
              padding: const EdgeInsets.only(right: 22),
              child: _CircleIconButton(icon: Icons.add, gradient: true, onTap: _openSubmit),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
            child: TextField(
              controller: _searchCtrl,
              autocorrect: false,
              enableSuggestions: false,
              style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Search tricks…',
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
          ),

          // Filters row
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  child: TextField(
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                    decoration: InputDecoration(
                      labelText: 'Min diff',
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line2)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line2)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _minDiff = int.tryParse(v)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 78,
                  child: TextField(
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                    decoration: InputDecoration(
                      labelText: 'Max diff',
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line2)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line2)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _maxDiff = int.tryParse(v)),
                  ),
                ),
                const SizedBox(width: 8),
                // Revolutions filter chip
                Expanded(
                  child: GestureDetector(
                    onTap: _showRevFilter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: _selectedRevs.isNotEmpty ? AppColors.indigoTint : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _selectedRevs.isNotEmpty ? const Color(0xFFC7CCF7) : AppColors.line2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            revsLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _selectedRevs.isNotEmpty ? AppColors.indigo : AppColors.ink2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.expand_more, size: 16, color: _selectedRevs.isNotEmpty ? AppColors.indigo : AppColors.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Type filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
        _typeChip(_TypeFilter.all, 'All'),
                        _typeChip(_TypeFilter.tricks, 'Tricks'),
                        _typeChip(_TypeFilter.combos, 'Combos'),
                      ],
                    ),
                  ),
                ),
                _nameFormatChip('Name', TrickNameDisplay.showFullName),
                const SizedBox(width: 6),
                _nameFormatChip('Abbr.', !TrickNameDisplay.showFullName),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _showSortSheet,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.tune, size: 18, color: AppColors.ink2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(_error!, style: const TextStyle(color: AppColors.red)),
            ),

          const SizedBox(height: 8),

          // Tricks/combos list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.indigo))
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final item = filtered[i];
                          if (item is TrickItem) {
                            return _buildTrickTile(item, admin);
                          } else if (item is ComboItem) {
                            return _buildComboTile(item, admin);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _RevOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RevOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.indigoTint : AppColors.surface,
            border: Border.all(color: selected ? const Color(0xFFC7CCF7) : AppColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.indigo : AppColors.ink,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 20,
                color: selected ? AppColors.indigo : AppColors.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool gradient;

  const _CircleIconButton({required this.icon, required this.onTap, this.gradient = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: gradient ? Colors.transparent : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: gradient ? BorderSide.none : const BorderSide(color: AppColors.line2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: gradient ? AppColors.grad : null,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 20, color: gradient ? Colors.white : AppColors.ink2),
        ),
      ),
    );
  }
}

// ── Edit dialog ────────────────────────────────────────────────────────────────

class _EditTrickDialog extends StatefulWidget {
  final TrickItem trick;
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
  late bool _crossOver = widget.trick.crossOver;
  late bool _knee = widget.trick.knee;

  // The trick list this dialog is opened from never carries commonLevel (or
  // createdBy/dateCreated/notes — see combo.dart), and PUT /api/tricks/{id} is
  // a full field-by-field replace, so we fetch the real current record first
  // rather than risk silently wiping fields we can't see from here.
  bool _loadingDetail = true;
  String? _detailError;
  TrickDto? _detail;
  int _commonLevel = 1;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await ApiClient.instance.getTrickById(widget.trick.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _commonLevel = detail.commonLevel;
        _loadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detailError = e.toString().replaceFirst('Exception: ', '');
        _loadingDetail = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrevCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final detail = _detail;
    if (detail == null) return;
    setState(() { _saving = true; _error = null; });
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
        isTransition: detail.isTransition,
        createdBy: detail.createdBy,
        dateCreated: detail.dateCreated,
        notes: detail.notes,
      );
      await ApiClient.instance.updateTrick(widget.trick.id, updated);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Edit trick', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
      content: SizedBox(
        width: 320,
        child: _loadingDetail
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: AppColors.indigo)),
              )
            : _detailError != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_detailError!, style: const TextStyle(color: AppColors.red)),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _EditDialogField(label: 'Abbreviation', controller: _abbrevCtrl),
                        const SizedBox(height: 10),
                        _EditDialogField(label: 'Name', controller: _nameCtrl),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                                child: _NumField(
                                    label: 'Revs',
                                    value: _revolution,
                                    min: 0.5,
                                    max: 10,
                                    step: 0.5,
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
                        const SizedBox(height: 6),
                        SubmitToggle(label: 'Cross-over', value: _crossOver, onChanged: (v) => setState(() => _crossOver = v)),
                        const SizedBox(height: 8),
                        SubmitToggle(label: 'Knee trick', value: _knee, onChanged: (v) => setState(() => _knee = v)),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!, style: const TextStyle(color: AppColors.red)),
                        ],
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.indigo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: (_saving || _detail == null) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _EditDialogField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _EditDialogField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.chipBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final double? step;

  const _NumField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value.toString()),
      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: AppColors.chipBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.line2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.line2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        var parsed = double.tryParse(v);
        if (parsed == null || parsed < min || parsed > max) return;
        if (step != null) parsed = (parsed / step!).round() * step!;
        onChanged(parsed);
      },
    );
  }
}
