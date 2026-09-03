import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';
import '../../core/models/user_preference.dart';
import '../../theme/app_colors.dart';
import '../../widgets/combo_card.dart' show TrickNameDisplay;
import '../../widgets/difficulty_chip.dart';
import '../../widgets/foot_toggle.dart';
import '../../widgets/setting_icon_button.dart';
import '../../widgets/submit_trick_sheet.dart';
import 'unsaved_combo_guard.dart';

enum _Mode { choose, generate, build }

enum _TypeFilter { all, tricks, combos }

class CreateComboScreen extends StatefulWidget {
  final CopyFromCombo? copyFrom;

  const CreateComboScreen({super.key, this.copyFrom});

  @override
  State<CreateComboScreen> createState() => _CreateComboScreenState();
}

// ── Slot item for build mode ────────────────────────────────────────────────

class _SlotItem {
  // For a trick slot
  final String? trickId;
  final String? trickName;
  final String? abbreviation;
  final bool crossOver;
  final bool isTransition;

  // For a sub-combo slot
  final String? subComboId;
  final String? subComboName;
  final List<ComboTrickDto>? subComboTricks;

  bool get isSubCombo => subComboId != null;

  // Matches the server's actual rule (BuildComboHandler/GenerateComboHandler):
  // a trick can be marked no-touch only if the trick immediately before it
  // is a CrossOver move — not based on the no-touch trick's own CrossOver
  // flag. A transition trick (e.g. "Combo") never enables it for the next
  // slot; a sub-combo slot enables it only if its own last trick is CrossOver.
  bool get allowsNoTouchOnNext {
    if (isTransition) return false;
    if (isSubCombo) {
      final tricks = subComboTricks;
      if (tricks == null || tricks.isEmpty) return false;
      return tricks.last.crossOver;
    }
    return crossOver;
  }

  int position;
  bool strongFoot;
  bool noTouch;
  bool expanded; // for sub-combo expand in slot list

  _SlotItem.trick({
    required String trickId,
    required String trickName,
    required String abbreviation,
    required this.crossOver,
    required this.position,
    this.strongFoot = true,
    this.noTouch = false,
    this.isTransition = false,
  })  : trickId = trickId,
        trickName = trickName,
        abbreviation = abbreviation,
        subComboId = null,
        subComboName = null,
        subComboTricks = null,
        expanded = false;

  _SlotItem.combo({
    required String subComboId,
    required String subComboName,
    required List<ComboTrickDto> subComboTricks,
    required this.position,
  })  : trickId = null,
        trickName = null,
        abbreviation = null,
        crossOver = false,
        isTransition = false,
        subComboId = subComboId,
        subComboName = subComboName,
        subComboTricks = subComboTricks,
        strongFoot = true,
        noTouch = false,
        expanded = false;
}

class _CreateComboScreenState extends State<CreateComboScreen> {
  _Mode _mode = _Mode.choose;

  // ── Shared name field ──────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();

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
  int _maxHighRevTricks = 1;
  List<String> _allowedTrickIds = [];
  List<TrickItem>? _allTricksForPicker;
  bool _genLoading = false;
  String? _genError;
  List<String> _previewWarnings = [];

  // ── Build state ────────────────────────────────────────────────────────────
  List<TrickListItem> _items = [];
  bool _loadingTricks = true;
  final _searchCtrl = TextEditingController();
  String _search = '';
  _TypeFilter _typeFilter = _TypeFilter.all;
  final List<_SlotItem> _slots = [];
  bool _isPublic = false;
  bool _isPersonalReusable = false;
  bool _saving = false;
  String? _buildError;
  ComboDto? _buildResult;
  int _buildTab = 0;

  @override
  void initState() {
    super.initState();
    final copyFrom = widget.copyFrom;
    if (copyFrom != null) {
      _nameCtrl.text = copyFrom.name ?? '';
      _populateSlotsFromComboTricks(copyFrom.tricks);
      _mode = _Mode.build;
      _buildTab = 1;
      _loadTricks();
    }
  }

  void _populateSlotsFromComboTricks(List<ComboTrickDto> tricks) {
    _slots.clear();
    for (final t in tricks) {
      if (t.type == 'combo') {
        _slots.add(_SlotItem.combo(
          subComboId: t.subComboId!,
          subComboName: t.subComboName ?? '',
          subComboTricks: t.subComboTricks ?? [],
          position: t.position,
        ));
      } else {
        _slots.add(_SlotItem.trick(
          trickId: t.trickId!,
          trickName: t.name ?? '',
          abbreviation: t.abbreviation ?? '',
          crossOver: t.crossOver,
          position: t.position,
          strongFoot: t.strongFoot,
          noTouch: t.noTouch,
          isTransition: t.isTransition,
        ));
      }
    }
  }

  @override
  void dispose() {
    UnsavedComboGuard.clear();
    _nameCtrl.dispose();
    _nameFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Generate actions ────────────────────────────────────────────────────────

  Future<void> _loadPreferences() async {
    if (!AuthService.instance.isAuthenticated) return;
    try {
      final prefs = await ApiClient.instance.getPreferences();
      if (mounted) setState(() => _savedPrefs = prefs);
    } catch (_) {
      // Non-critical — user can still generate with custom settings
    }
  }

  Future<void> _showTrickPicker() async {
    if (_allTricksForPicker == null) {
      final all = await ApiClient.instance.getTricks();
      _allTricksForPicker = all.whereType<TrickItem>().where((t) => !t.isTransition).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }
    if (!mounted) return;
    var search = '';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final pickerQ = search.toLowerCase();
          var filtered = _allTricksForPicker!.where((t) {
            if (pickerQ.isEmpty) return true;
            return t.name.toLowerCase().contains(pickerQ) || t.abbreviation.toLowerCase().contains(pickerQ);
          }).toList();
          if (pickerQ.isNotEmpty) {
            bool exact(TrickItem t) => t.abbreviation.toLowerCase() == pickerQ || t.name.toLowerCase() == pickerQ;
            filtered = [...filtered.where(exact), ...filtered.where((t) => !exact(t))];
          }
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Allowed tricks',
                            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ),
                        if (_allowedTrickIds.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() => _allowedTrickIds = []);
                              setSt(() {});
                            },
                            child: const Text('Clear'),
                          ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            'OK',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.indigo),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                    child: Text(
                      'Leave everything unchecked to allow the full trick library.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: TextField(
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (v) => setSt(() => search = v),
                      decoration: InputDecoration(
                        hintText: 'Search tricks...',
                        filled: true,
                        fillColor: AppColors.chipBg,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text('No tricks match', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.muted)),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final t = filtered[i];
                              final selected = _allowedTrickIds.contains(t.id);
                              return CheckboxListTile(
                                value: selected,
                                activeColor: AppColors.indigo,
                                controlAffinity: ListTileControlAffinity.leading,
                                dense: true,
                                title: Text(
                                  '${t.abbreviation} · ${t.name}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                                ),
                                onChanged: (v) {
                                  setState(() {
                                    _allowedTrickIds = v == true
                                        ? [..._allowedTrickIds, t.id]
                                        : _allowedTrickIds.where((id) => id != t.id).toList();
                                  });
                                  setSt(() {});
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _preview() async {
    setState(() {
      _genLoading = true;
      _genError = null;
    });
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
              maxHighRevolutionTricks: _maxHighRevTricks,
              allowedTrickIds: _allowedTrickIds,
            );
      final result =
          await ApiClient.instance.previewCombo(_selectedPrefId, overrides);
      _slots.clear();
      for (final t in result.tricks) {
        _slots.add(_SlotItem.trick(
          trickId: t.trickId,
          trickName: t.trickName,
          abbreviation: t.abbreviation,
          crossOver: t.crossOver,
          position: t.position,
          strongFoot: t.strongFoot,
          noTouch: t.noTouch,
          isTransition: t.isTransition,
        ));
      }
      setState(() {
        _previewWarnings = result.warnings;
        _mode = _Mode.build;
        _buildTab = 1;
      });
      if (_items.isEmpty) _loadTricks();
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
      final items = await ApiClient.instance.getTricks();
      if (mounted) setState(() => _items = items);
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

  Future<void> _promptAddTrick(TrickItem trick) async {
    // A "transition" trick (e.g. "Combo") is a simple connector between real
    // tricks, not a move with its own foot/no-touch — add it straight away.
    if (trick.isTransition) {
      setState(() {
        _slots.add(_SlotItem.trick(
          trickId: trick.id,
          trickName: trick.name,
          abbreviation: trick.abbreviation,
          crossOver: trick.crossOver,
          position: _slots.length + 1,
          isTransition: true,
        ));
      });
      return;
    }
    // No-touch is valid only if the *preceding* trick is a CrossOver move
    // (matches the server's rule) — the trick being added has no say in it.
    final allowNoTouch = _slots.isNotEmpty && _slots.last.allowsNoTouchOnNext;
    final infoParts = [
      '${trick.revolution} rev${trick.revolution == 1 ? '' : 's'}',
      'difficulty ${trick.difficulty}',
      if (trick.commonLevel != null) 'common ${trick.commonLevel}',
      if (trick.crossOver) 'crossover',
    ];
    final choice = await _showAddOptionsSheet(
      title: trick.name,
      allowNoTouch: allowNoTouch,
      info: infoParts.join(' · '),
    );
    if (choice == null) return;
    setState(() {
      _slots.add(_SlotItem.trick(
        trickId: trick.id,
        trickName: trick.name,
        abbreviation: trick.abbreviation,
        crossOver: trick.crossOver,
        position: _slots.length + 1,
        strongFoot: choice.strongFoot,
        noTouch: choice.noTouch,
      ));
    });
  }

  Future<void> _promptAddCombo(ComboItem combo) async {
    final choice = await _showAddOptionsSheet(
      title: combo.displayName,
      allowNoTouch: false,
    );
    if (choice == null) return;
    setState(() {
      _slots.add(_SlotItem.combo(
        subComboId: combo.id,
        subComboName: combo.displayName,
        subComboTricks: combo.tricks,
        position: _slots.length + 1,
      )..strongFoot = choice.strongFoot);
    });
  }

  Future<_AddOptionsChoice?> _showAddOptionsSheet({
    required String title,
    required bool allowNoTouch,
    String? info,
  }) {
    var strongFoot = true;
    var noTouch = false;
    return showModalBottomSheet<_AddOptionsChoice>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(
              22, 20, 22, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.line2,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
              if (info != null) ...[
                const SizedBox(height: 4),
                Text(
                  info,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 22),
              _FieldLabel('Foot'),
              const SizedBox(height: 10),
              Center(
                child: FootToggle(
                  value: strongFoot,
                  onTap: () => setSt(() => strongFoot = !strongFoot),
                  scale: 1.9,
                ),
              ),
              if (allowNoTouch) ...[
                const SizedBox(height: 18),
                _ToggleRow(
                  label: 'No touch',
                  value: noTouch,
                  onChanged: (v) => setSt(() => noTouch = v),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(
                      ctx,
                      _AddOptionsChoice(
                          strongFoot: strongFoot, noTouch: noTouch)),
                  child: const Text('Add to combo',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index);
      _renumberSlots();
    });
  }

  void _reorderSlot(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _slots.removeAt(oldIndex);
      _slots.insert(newIndex, item);
      _renumberSlots();
    });
  }

  void _renumberSlots() {
    for (var i = 0; i < _slots.length; i++) {
      _slots[i].position = i + 1;
      // No-touch is only valid right after a CrossOver trick — clear it if
      // reordering/removal put something else before this one now.
      final allowed = i > 0 && _slots[i - 1].allowsNoTouchOnNext;
      if (!_slots[i].isSubCombo && !allowed && _slots[i].noTouch) {
        _slots[i].noTouch = false;
      }
    }
  }

  Future<bool> _confirmSaveWithoutName() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Save without a name?',
            style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: Text(
          "You haven't given this combo a name. Save it anyway?",
          style: GoogleFonts.plusJakartaSans(color: AppColors.ink2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Add a name'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save anyway', style: GoogleFonts.plusJakartaSans(color: AppColors.indigo, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _save() async {
    if (_slots.isEmpty) return;

    if (_nameCtrl.text.trim().isEmpty) {
      final proceed = await _confirmSaveWithoutName();
      if (!proceed) {
        if (mounted) FocusScope.of(context).requestFocus(_nameFocus);
        return;
      }
    }

    if (!AuthService.instance.isAuthenticated) {
      final name = _nameCtrl.text.trim();
      await AuthService.instance.setPendingCombo({
        'tricks': _slots
            .where((s) => !s.isSubCombo)
            .map((s) => {
                  'trickId': s.trickId,
                  'position': s.position,
                  'strongFoot': s.strongFoot,
                  'noTouch': s.noTouch,
                })
            .toList(),
        'name': name.isEmpty ? null : name,
        'isPublic': _isPublic,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign up to save your combo!')),
        );
        context.push('/register');
      }
      return;
    }

    setState(() {
      _saving = true;
      _buildError = null;
    });
    try {
      final items = _slots.map((s) {
        if (s.isSubCombo) {
          return BuildComboTrickItem(
            subComboId: s.subComboId,
            position: s.position,
            strongFoot: s.strongFoot,
            noTouch: s.noTouch,
          );
        }
        return BuildComboTrickItem(
          trickId: s.trickId,
          position: s.position,
          strongFoot: s.strongFoot,
          noTouch: s.noTouch,
        );
      }).toList();
      final name = _nameCtrl.text.trim();
      final combo = await ApiClient.instance
          .buildCombo(items, _isPublic, name: name.isEmpty ? null : name);
      if (_isPersonalReusable) {
        await ApiClient.instance.addPersonalReusable(combo.id);
      }
      setState(() => _buildResult = combo);
    } catch (e) {
      setState(
          () => _buildError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<TrickListItem> get _filtered {
    final q = _search.toLowerCase();
    final list = _items.where((item) {
      if (item is TrickItem) {
        if (_typeFilter == _TypeFilter.combos) return false;
        if (q.isEmpty) return true;
        return item.name.toLowerCase().contains(q) ||
            item.abbreviation.toLowerCase().contains(q);
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

  int get _totalDiff {
    int total = 0;
    for (final s in _slots) {
      if (s.isSubCombo) {
        for (final ComboTrickDto t in s.subComboTricks ?? []) {
          total += t.difficulty;
        }
      } else {
        final trick = _items
            .whereType<TrickItem>()
            .where((t) => t.id == s.trickId)
            .firstOrNull;
        if (trick != null) total += trick.difficulty;
      }
    }
    return total;
  }

  int get _totalTrickCount {
    int count = 0;
    for (final s in _slots) {
      if (s.isSubCombo) {
        count += s.subComboTricks?.length ?? 0;
      } else {
        count++;
      }
    }
    return count;
  }

  Widget _buildGuestBanner() {
    if (AuthService.instance.isAuthenticated) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.indigoTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7DBFA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.indigo),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Create a free account to save your combos.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink2),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/register'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.indigo,
            ),
            child: const Text('Sign up',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Mode switching ────────────────────────────────────────────────────────────

  void _switchToBuild() {
    setState(() => _mode = _Mode.build);
    if (_items.isEmpty) _loadTricks();
  }

  Future<void> _backToChoose() async {
    if (_slots.isNotEmpty && _buildResult == null) {
      if (!await _confirmDiscardCombo()) return;
    }
    setState(() {
      _mode = _Mode.choose;
      _slots.clear();
      _previewWarnings = [];
      _buildResult = null;
      _buildTab = 0;
    });
  }

  Future<bool> _confirmDiscardCombo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Discard combo?',
            style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: Text(
          'You have ${_slots.length} trick${_slots.length == 1 ? '' : 's'} in this combo. Leaving now will discard it.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.ink2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _Mode.choose => 'Create Combo',
      _Mode.generate => 'Generate',
      _Mode.build => 'Build combo',
    };
    UnsavedComboGuard.pendingTrickCount =
        (_mode == _Mode.build && _buildResult == null) ? _slots.length : 0;

    return PopScope(
      canPop: _mode == _Mode.choose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _mode != _Mode.choose) _backToChoose();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text(title),
          leading:
              _mode != _Mode.choose ? _BackButton(onTap: _backToChoose) : null,
        ),
        body: _mode == _Mode.choose
            ? _buildChooseView()
            : _mode == _Mode.generate
                ? _buildGenerateView()
                : _buildBuildView(),
        bottomNavigationBar:
            _mode == _Mode.generate ? _buildGenerateActionBar() : null,
      ),
    );
  }

  Widget _buildGenerateActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.indigo,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _genLoading ? null : _preview,
            icon: _genLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bolt),
            label: Text(
              _genLoading ? 'Generating…' : 'Generate combo',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  // ── Choose view ────────────────────────────────────────────────────────────────

  Widget _buildChooseView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGuestBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How would you like to create your combo?',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 20),
                _ModeCard(
                  icon: Icons.auto_awesome,
                  title: 'Auto-generate',
                  description:
                      'Let the app build a combo based on your settings.',
                  onTap: () {
                    setState(() => _mode = _Mode.generate);
                    _loadPreferences();
                  },
                ),
                const SizedBox(height: 14),
                _ModeCard(
                  icon: Icons.build_outlined,
                  title: 'Build manually',
                  description:
                      'Pick tricks one by one and configure each slot.',
                  onTap: _switchToBuild,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Generate view ────────────────────────────────────────────────────────────

  Widget _buildGenerateView() {
    final authed = AuthService.instance.isAuthenticated;
    final locked = _selectedPrefId != null;
    final selectedPref = _selectedPrefId == null
        ? null
        : _savedPrefs.where((p) => p.id == _selectedPrefId).firstOrNull;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGuestBanner(),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FieldLabel('Combo name'),
                const SizedBox(height: 8),
                _AppTextField(
                    controller: _nameCtrl, hint: 'e.g. My signature combo', focusNode: _nameFocus),
                if (authed) ...[
                  const SizedBox(height: 22),
                  _FieldLabel('Base preset'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _PresetChip(
                          label: 'Custom',
                          selected: _selectedPrefId == null,
                          onTap: () => setState(() {
                            _selectedPrefId = null;
                            _comboLength = 5;
                            _maxDifficulty = 10;
                            _strongFootPct = 50;
                            _noTouchPct = 30;
                            _maxConsecNoTouch = 2;
                            _includeCrossOver = true;
                            _includeKnee = true;
                            _maxHighRevTricks = 1;
                            _allowedTrickIds = [];
                          }),
                        ),
                        for (final p in _savedPrefs) ...[
                          const SizedBox(width: 8),
                          _PresetChip(
                            label: p.name,
                            selected: _selectedPrefId == p.id,
                            onTap: () => setState(() {
                              _selectedPrefId = p.id;
                              _comboLength = p.comboLength;
                              _maxDifficulty = p.maxDifficulty;
                              _strongFootPct = p.strongFootPercentage;
                              _noTouchPct = p.noTouchPercentage;
                              _maxConsecNoTouch = p.maxConsecutiveNoTouch;
                              _includeCrossOver = p.includeCrossOver;
                              _includeKnee = p.includeKnee;
                              _maxHighRevTricks = p.maxHighRevolutionTricks ?? 1;
                              _allowedTrickIds = List.from(p.allowedTrickIds);
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                _AppSlider(
                  label: 'Combo length',
                  value: _comboLength.toDouble(),
                  min: 1,
                  max: 100,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _comboLength = v.round()),
                ),
                const SizedBox(height: 20),
                _AppSlider(
                  label: 'Max difficulty',
                  value: _maxDifficulty.toDouble(),
                  min: 1,
                  max: 10,
                  formatValue: (v) => '${v.round()} / 10',
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _maxDifficulty = v.round()),
                ),
                const SizedBox(height: 20),
                _AppSlider(
                  label: 'Strong foot',
                  value: _strongFootPct.toDouble(),
                  min: 0,
                  max: 100,
                  formatValue: (v) => '${v.round()}%',
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _strongFootPct = v.round()),
                ),
                const SizedBox(height: 20),
                _AppSlider(
                  label: 'No-touch',
                  value: _noTouchPct.toDouble(),
                  min: 0,
                  max: 100,
                  formatValue: (v) => '${v.round()}%',
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _noTouchPct = v.round()),
                ),
                const SizedBox(height: 20),
                _AppSlider(
                  label: 'Max consecutive no-touch',
                  value: _maxConsecNoTouch.toDouble(),
                  min: 0,
                  max: 30,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _maxConsecNoTouch = v.round()),
                ),
                const SizedBox(height: 20),
                _AppSlider(
                  label: 'Max 3+ rev tricks',
                  value: _maxHighRevTricks.toDouble(),
                  min: 1,
                  max: 15,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _maxHighRevTricks = v.round()),
                ),
                const SizedBox(height: 20),
                _ToggleRow(
                  label: 'Include cross-overs',
                  value: _includeCrossOver,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _includeCrossOver = v),
                ),
                const SizedBox(height: 11),
                _ToggleRow(
                  label: 'Include knee tricks',
                  value: _includeKnee,
                  onChanged:
                      locked ? null : (v) => setState(() => _includeKnee = v),
                ),
                const SizedBox(height: 20),
                if (locked && selectedPref != null && selectedPref.allowedTrickIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt, size: 16, color: AppColors.indigo),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Allowed tricks: only ${selectedPref.allowedTrickIds.length} selected in "${selectedPref.name}"',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink2),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!locked)
                  Material(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: _showTrickPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_alt, size: 16, color: AppColors.indigo),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _allowedTrickIds.isEmpty
                                    ? 'Allowed tricks (all)'
                                    : 'Allowed tricks (${_allowedTrickIds.length} selected)',
                                style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Fields are locked to the selected preset. Choose "Custom" to edit.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5, color: AppColors.faint),
                    ),
                  ),
                if (_genError != null) ...[
                  const SizedBox(height: 14),
                  Text(_genError!,
                      style: const TextStyle(color: AppColors.red)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Build view ────────────────────────────────────────────────────────────────

  Widget _buildBuildView() {
    if (_buildResult != null) {
      return _buildSavedView();
    }

    return Column(
      children: [
        _buildGuestBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: _AppTextField(
            controller: _nameCtrl,
            hint: 'Combo name (optional)',
            focusNode: _nameFocus,
          ),
        ),
        if (_previewWarnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amberBg,
                borderRadius: BorderRadius.circular(12),
                border: const Border.fromBorderSide(
                    BorderSide(color: Color(0xFFFDE68A))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _previewWarnings
                    .map((w) => Text(w,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: AppColors.amber)))
                    .toList(),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: _Segmented2(
            labels: [
              'Tricks (${_items.length})',
              'My Combo ($_totalTrickCount)'
            ],
            pulseCounts: [null, _totalTrickCount],
            selectedIndex: _buildTab,
            onSelected: (i) => setState(() => _buildTab = i),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _nameFormatChip('Full name', TrickNameDisplay.showFullName),
              const SizedBox(width: 6),
              _nameFormatChip('Abbr.', !TrickNameDisplay.showFullName),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
    );
  }

  Widget _buildSavedView() {
    final result = _buildResult!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    gradient: AppColors.grad, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Text('Saved!',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            (result.name != null && result.name!.isNotEmpty)
                ? result.name!
                : result.displayText,
            style: GoogleFonts.jetBrainsMono(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            '${result.trickCount} tricks · difficulty ${result.totalDifficulty.toInt()}',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.muted,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.indigo,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('View combo',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              // Replace (not push) so the back button from the detail screen
              // returns to wherever "Generate"/"Build" was opened from,
              // instead of back to this "Saved!" confirmation screen.
              onPressed: () =>
                  context.pushReplacement('/combos/${result.id}'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.line2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => setState(() {
                _buildResult = null;
                _slots.clear();
                _buildTab = 0;
                _previewWarnings = [];
              }),
              child: const Text('Build another',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameFormatChip(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => TrickNameDisplay.showFullName = label == 'Full name'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.indigo : AppColors.chipBg,
          borderRadius: BorderRadius.circular(9),
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
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }

  Widget _buildPickerTab() {
    final filtered = _filtered;
    // Transition tricks (e.g. "Combo") are simple connectors, not full moves —
    // pinned above the scrolling list so they stay visible while scrolling,
    // and added with a single tap (see _promptAddTrick).
    final pinned =
        filtered.whereType<TrickItem>().where((t) => t.isTransition).toList();
    final rest = filtered
        .where((item) => !(item is TrickItem && item.isTransition))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: _SearchField(
            controller: _searchCtrl,
            value: _search,
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              _typeChip(_TypeFilter.all, 'All'),
              const SizedBox(width: 6),
              _typeChip(_TypeFilter.tricks, 'Tricks'),
              const SizedBox(width: 6),
              _typeChip(_TypeFilter.combos, 'Combos'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (pinned.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: Column(
              children: pinned
                  .map((t) =>
                      _PickerTrickRow(item: t, onAdd: () => _promptAddTrick(t)))
                  .toList(),
            ),
          ),
        Expanded(
          child: _loadingTricks
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.indigo))
              : filtered.isEmpty
                  ? _buildPickerEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                      itemCount: rest.length,
                      itemBuilder: (_, i) {
                        final item = rest[i];
                        if (item is TrickItem) {
                          return _PickerTrickRow(
                              item: item, onAdd: () => _promptAddTrick(item));
                        } else if (item is ComboItem) {
                          return _PickerComboRow(
                              item: item, onAdd: () => _promptAddCombo(item));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPickerEmptyState() {
    final query = _search.trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              query.isEmpty ? 'No tricks found.' : 'No tricks found for "$query".',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Missing a trick?',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: AppColors.ink2, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => showSubmitTrickSheet(
                  context,
                  initialName: query,
                  onSubmitted: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trick submitted for review!')),
                    );
                  },
                ),
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
                        'Submit "$query"',
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

  Widget _buildComboTab() {
    return Column(
      children: [
        if (_slots.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'Add tricks from the first tab.',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
              itemCount: _slots.length,
              onReorder: _reorderSlot,
              itemBuilder: (_, i) {
                final s = _slots[i];
                final noTouchAllowed = i > 0 && _slots[i - 1].allowsNoTouchOnNext;
                if (s.isSubCombo) {
                  return _SubComboSlotTile(
                    key: ObjectKey(s),
                    index: i,
                    slot: s,
                    onRemove: () => _removeSlot(i),
                    onToggleExpand: () =>
                        setState(() => s.expanded = !s.expanded),
                  );
                }
                return _SlotTile(
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
            ),
          ),
        if (_slots.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$_totalTrickCount tricks · difficulty $_totalDiff',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SettingIconButton(
                      activeIcon: Icons.public,
                      inactiveIcon: Icons.public_off,
                      active: _isPublic,
                      activeColor: AppColors.indigo,
                      title: _isPublic ? 'Stop submitting as public?' : 'Submit as public?',
                      description: _isPublic
                          ? "This combo will be saved as private instead — it won't be sent for admin review or shown to other users."
                          : 'An admin will review this combo before it becomes visible to everyone. Until approved, only you can see it.',
                      onChanged: (v) => setState(() => _isPublic = v),
                    ),
                    const SizedBox(width: 12),
                    SettingIconButton(
                      activeIcon: Icons.link,
                      inactiveIcon: Icons.link_off,
                      active: _isPersonalReusable,
                      activeColor: AppColors.violet,
                      title: _isPersonalReusable ? 'Remove from your trick list?' : 'List combo in your trick list?',
                      description: _isPersonalReusable
                          ? "This combo will no longer show up when you're building other combos."
                          : "This combo will show up as a selectable item — alongside tricks — when you're building other combos. Only you will see it there.",
                      onChanged: (v) => setState(() => _isPersonalReusable = v),
                    ),
                  ],
                ),
                if (_buildError != null) ...[
                  const SizedBox(height: 8),
                  Text(_buildError!,
                      style:
                          const TextStyle(color: AppColors.red, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.indigo,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            AuthService.instance.isAuthenticated
                                ? 'Save combo'
                                : 'Sign up to save',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Sub-combo slot tile ────────────────────────────────────────────────────────

class _SubComboSlotTile extends StatelessWidget {
  final int index;
  final _SlotItem slot;
  final VoidCallback onRemove;
  final VoidCallback onToggleExpand;

  const _SubComboSlotTile({
    super.key,
    required this.index,
    required this.slot,
    required this.onRemove,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.noTouchBg,
        border: Border.all(color: const Color(0xFFE5E0FB)),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_indicator, size: 18, color: AppColors.noTouchText),
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${slot.position}',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noTouchText),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'COMBO',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noTouchText,
                        letterSpacing: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slot.subComboName ?? '',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                      slot.expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: AppColors.noTouchText),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onToggleExpand,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon:
                      const Icon(Icons.close, size: 18, color: AppColors.muted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
          if (slot.expanded && slot.subComboTricks != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: slot.subComboTricks!.map((t) {
                  final suffix =
                      t.noTouch ? '·nt' : (!t.strongFoot ? '·wf' : '');
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(9)),
                    child: Text(
                      '${t.position}. ${t.abbreviation ?? ''}$suffix',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink2),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Regular slot tile (Build screen "slot" row) ─────────────────────────────────

class _SlotTile extends StatelessWidget {
  final int index;
  final _SlotItem slot;
  final bool showAbbrev;
  final bool noTouchAllowed;
  final VoidCallback onRemove;
  final ValueChanged<bool> onToggleStrongFoot;
  final ValueChanged<bool> onToggleNoTouch;

  const _SlotTile({
    super.key,
    required this.index,
    required this.slot,
    required this.showAbbrev,
    required this.noTouchAllowed,
    required this.onRemove,
    required this.onToggleStrongFoot,
    required this.onToggleNoTouch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_indicator, size: 18, color: AppColors.faint),
          ),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.indigoTint,
                borderRadius: BorderRadius.circular(9)),
            child: Text(
              '${slot.position}',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.indigo),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              slot.isTransition
                  ? (slot.abbreviation ?? '')
                  : ((showAbbrev ? slot.abbreviation : slot.trickName) ?? ''),
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // A transition trick (e.g. "Combo") is a connector, not a move —
          // strong/weak foot and no-touch don't apply to it.
          if (!slot.isTransition) ...[
            _SlotFlagToggle(
              label: 'WF',
              active: !slot.strongFoot,
              onTap: () => onToggleStrongFoot(!slot.strongFoot),
            ),
            _SlotFlagToggle(
              label: 'NT',
              active: slot.noTouch,
              enabled: noTouchAllowed,
              onTap: noTouchAllowed ? () => onToggleNoTouch(!slot.noTouch) : null,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _SlotFlagToggle extends StatelessWidget {
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  const _SlotFlagToggle(
      {required this.label,
      required this.active,
      this.enabled = true,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.indigoTint : Colors.transparent;
    final fg = !enabled
        ? AppColors.faint
        : (active ? AppColors.indigo : AppColors.muted);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5, fontWeight: FontWeight.w800, color: fg),
        ),
      ),
    );
  }
}

// ── Picker rows ──────────────────────────────────────────────────────────────────

class _PickerTrickRow extends StatelessWidget {
  final TrickItem item;
  final VoidCallback onAdd;
  const _PickerTrickRow({required this.item, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
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
                  decoration: BoxDecoration(
                      color: AppColors.chipBg,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    item.abbreviation,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 8.5,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.indigo),
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
                        TrickNameDisplay.label(isTransition: item.isTransition, name: item.name, abbreviation: item.abbreviation),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.revolution} rev${item.crossOver ? ' · crossover' : ''}${item.knee ? ' · knee' : ''}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                DifficultyChip(item.difficulty),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerComboRow extends StatelessWidget {
  final ComboItem item;
  final VoidCallback onAdd;
  const _PickerComboRow({required this.item, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF7F5FE),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E0FB)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.layers,
                      size: 18, color: AppColors.noTouchText),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.displayName,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              'COMBO',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.noTouchText),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.trickCount} tricks',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DifficultyChip(item.totalDifficulty.toInt()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: const BorderSide(color: AppColors.line2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: AppColors.ink)),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.faint),
    );
  }
}

class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  const _AppTextField({required this.controller, required this.hint, this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
              color: AppColors.faint, fontWeight: FontWeight.w600),
          prefixIcon: const Icon(Icons.edit_outlined,
              size: 19, color: AppColors.indigo),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: AppColors.line2)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: AppColors.line2)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide:
                  const BorderSide(color: AppColors.indigo, width: 1.5)),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String value;
  final ValueChanged<String> onChanged;

  const _SearchField(
      {required this.controller, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: 'Search…',
        hintStyle: GoogleFonts.plusJakartaSans(
            color: AppColors.faint, fontWeight: FontWeight.w600),
        prefixIcon: const Icon(Icons.search, color: AppColors.faint),
        suffixIcon: value.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppColors.faint),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.line2)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.line2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
      ),
      onChanged: onChanged,
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ModeCard(
      {required this.icon,
      required this.title,
      required this.description,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    gradient: AppColors.grad,
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            color: AppColors.ink)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PresetChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigo : AppColors.chipBg,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

class _AppSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final String Function(double)? formatValue;

  const _AppSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.onChanged,
    this.formatValue,
  });

  void _handle(Offset local, double width) {
    if (onChanged == null || width <= 0) return;
    final pct = (local.dx / width).clamp(0.0, 1.0);
    onChanged!(min + pct * (max - min));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final valueLabel =
        formatValue != null ? formatValue!(value) : value.round().toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            Text(
              valueLabel,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: enabled ? AppColors.indigo : AppColors.faint),
            ),
          ],
        ),
        const SizedBox(height: 11),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onTapDown:
                  enabled ? (d) => _handle(d.localPosition, width) : null,
              onHorizontalDragUpdate:
                  enabled ? (d) => _handle(d.localPosition, width) : null,
              child: SizedBox(
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE4E3EF),
                            borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 0,
                      child: Container(
                        width: (pct * width).clamp(0.0, width),
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: enabled ? AppColors.grad : null,
                          color: enabled ? null : AppColors.line2,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (pct * width - 12)
                          .clamp(0.0, width - 24 < 0 ? 0.0 : width - 24),
                      top: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                              color:
                                  enabled ? AppColors.indigo : AppColors.faint,
                              width: 4),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x40141221),
                                blurRadius: 8,
                                offset: Offset(0, 3))
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({required this.label, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              IgnorePointer(
                child: CupertinoSwitch(
                  value: value,
                  activeTrackColor: AppColors.indigo,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segmented2 extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Optional per-tab counter — when the value for a tab changes, that tab's
  /// label plays a pop/flash animation so additions are noticeable even
  /// without navigating to that tab.
  final List<int?>? pulseCounts;

  const _Segmented2({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.pulseCounts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFE7E6F0),
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color:
                        i == selectedIndex ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == selectedIndex
                        ? [
                            BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.12),
                                blurRadius: 3,
                                offset: const Offset(0, 1))
                          ]
                        : null,
                  ),
                  child: _PulseOnChange(
                    pulseKey: pulseCounts?[i],
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: i == selectedIndex
                            ? AppColors.ink
                            : AppColors.muted,
                      ),
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

/// Wraps [child] with a pop + flash animation that replays every time
/// [pulseKey] changes value — used to draw the eye to a tab label when a
/// count updates without navigating away from the current tab.
class _PulseOnChange extends StatefulWidget {
  final Object? pulseKey;
  final Widget child;

  const _PulseOnChange({required this.pulseKey, required this.child});

  @override
  State<_PulseOnChange> createState() => _PulseOnChangeState();
}

class _PulseOnChangeState extends State<_PulseOnChange> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    // Deliberately not forwarded here — mounting with an already-populated
    // count (e.g. landing on this tab right after Generate) must not pulse;
    // only a genuine key change on an already-mounted widget should.
  }

  @override
  void didUpdateWidget(covariant _PulseOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulseKey != oldWidget.pulseKey) {
      _controller
        ..value = 1.0
        ..animateTo(0.0, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pulseKey == null) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, builtChild) {
        final t = _controller.value;
        final scale = 1.0 + 0.4 * t;
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.indigo.withValues(alpha: 0.2 * t),
            ),
            child: builtChild,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _AddOptionsChoice {
  final bool strongFoot;
  final bool noTouch;
  const _AddOptionsChoice({required this.strongFoot, required this.noTouch});
}
