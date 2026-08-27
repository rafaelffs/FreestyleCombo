import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user_preference.dart';
import '../../theme/app_colors.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  List<UserPreference> _prefs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await ApiClient.instance.getPreferences();
      if (mounted) setState(() => _prefs = prefs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForm({UserPreference? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _PreferenceForm(
        initial: existing,
        onSaved: (_) {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  Future<void> _delete(UserPreference pref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete preference'),
        content: Text('Delete "${pref.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.deletePreference(pref.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text('Presets'),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Your generation profiles',
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
            padding: const EdgeInsets.only(right: 22),
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => _openForm(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.add, size: 20, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.indigo,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.indigo))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
                : _prefs.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.symmetric(vertical: 80),
                        children: [
                          Center(
                            child: Text(
                              'No preferences saved yet.\nTap + to create one.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(color: AppColors.muted, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                        itemCount: _prefs.length,
                        itemBuilder: (_, i) => _PrefCard(
                          pref: _prefs[i],
                          onEdit: () => _openForm(existing: _prefs[i]),
                          onDelete: () => _delete(_prefs[i]),
                        ),
                      ),
      ),
    );
  }
}

// ── Preference card ────────────────────────────────────────────────────────────

class _PrefCard extends StatelessWidget {
  final UserPreference pref;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PrefCard({required this.pref, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final flags = '${pref.includeCrossOver ? "Cross-overs" : "No cross-overs"} · '
        '${pref.includeKnee ? "Knee tricks" : "No knee tricks"} · '
        'Max consec. NT ${pref.maxConsecutiveNoTouch}';

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -18),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(gradient: AppColors.grad, shape: BoxShape.circle),
                child: const Icon(Icons.tune, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  pref.name,
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.indigo,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
                child: const Text('Edit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.muted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _PStat(value: '${pref.comboLength}', label: 'Length')),
              const SizedBox(width: 8),
              Expanded(child: _PStat(value: '${pref.maxDifficulty}', label: 'Max diff')),
              const SizedBox(width: 8),
              Expanded(child: _PStat(value: '${pref.noTouchPercentage}%', label: 'No-touch')),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            flags,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.faint, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PStat extends StatelessWidget {
  final String value;
  final String label;
  const _PStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 1),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ── Preference form (create / edit) ───────────────────────────────────────────

class _PreferenceForm extends StatefulWidget {
  final UserPreference? initial;
  final void Function(UserPreference saved) onSaved;

  const _PreferenceForm({this.initial, required this.onSaved});

  @override
  State<_PreferenceForm> createState() => _PreferenceFormState();
}

class _PreferenceFormState extends State<_PreferenceForm> {
  final _nameCtrl = TextEditingController();
  int _comboLength = 6;
  int _maxDifficulty = 10;
  int _strongFootPct = 60;
  int _noTouchPct = 30;
  int _maxConsecNoTouch = 2;
  bool _includeCrossOver = true;
  bool _includeKnee = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    if (p != null) {
      _nameCtrl.text = p.name;
      _comboLength = p.comboLength;
      _maxDifficulty = p.maxDifficulty;
      _strongFootPct = p.strongFootPercentage;
      _noTouchPct = p.noTouchPercentage;
      _maxConsecNoTouch = p.maxConsecutiveNoTouch;
      _includeCrossOver = p.includeCrossOver;
      _includeKnee = p.includeKnee;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final pref = UserPreference(
        id: widget.initial?.id ?? '',
        userId: widget.initial?.userId ?? AuthService.instance.userId ?? '',
        name: name,
        comboLength: _comboLength,
        maxDifficulty: _maxDifficulty,
        strongFootPercentage: _strongFootPct,
        noTouchPercentage: _noTouchPct,
        maxConsecutiveNoTouch: _maxConsecNoTouch,
        includeCrossOver: _includeCrossOver,
        includeKnee: _includeKnee,
        allowedRevolutions: widget.initial?.allowedRevolutions ?? [],
      );

      UserPreference saved;
      if (widget.initial != null) {
        saved = await ApiClient.instance.updatePreference(pref.id, pref);
      } else {
        saved = await ApiClient.instance.createPreference(pref);
      }
      widget.onSaved(saved);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 22, right: 22, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isEdit ? 'Edit preference' : 'New preference',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. NT Combinations',
                filled: true,
                fillColor: AppColors.chipBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
              ),
            ),
            const SizedBox(height: 6),
            _PrefSlider(label: 'Combo length', value: _comboLength.toDouble(), min: 1, max: 100, onChanged: (v) => setState(() => _comboLength = v.round())),
            const SizedBox(height: 18),
            _PrefSlider(label: 'Max difficulty', value: _maxDifficulty.toDouble(), min: 1, max: 10, formatValue: (v) => '${v.round()} / 10', onChanged: (v) => setState(() => _maxDifficulty = v.round())),
            const SizedBox(height: 18),
            _PrefSlider(label: 'Strong foot', value: _strongFootPct.toDouble(), min: 0, max: 100, formatValue: (v) => '${v.round()}%', onChanged: (v) => setState(() => _strongFootPct = v.round())),
            const SizedBox(height: 18),
            _PrefSlider(label: 'No-touch', value: _noTouchPct.toDouble(), min: 0, max: 100, formatValue: (v) => '${v.round()}%', onChanged: (v) => setState(() => _noTouchPct = v.round())),
            const SizedBox(height: 18),
            _PrefSlider(label: 'Max consecutive no-touch', value: _maxConsecNoTouch.toDouble(), min: 0, max: 30, onChanged: (v) => setState(() => _maxConsecNoTouch = v.round())),
            const SizedBox(height: 18),
            _PrefToggle(label: 'Include cross-overs', value: _includeCrossOver, onChanged: (v) => setState(() => _includeCrossOver = v)),
            const SizedBox(height: 11),
            _PrefToggle(label: 'Include knee tricks', value: _includeKnee, onChanged: (v) => setState(() => _includeKnee = v)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Save changes' : 'Create preference', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double)? formatValue;

  const _PrefSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.formatValue,
  });

  void _handle(Offset local, double width) {
    if (width <= 0) return;
    final pct = (local.dx / width).clamp(0.0, 1.0);
    onChanged(min + pct * (max - min));
  }

  @override
  Widget build(BuildContext context) {
    final pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final valueLabel = formatValue != null ? formatValue!(value) : value.round().toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
            Text(valueLabel, style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.indigo)),
          ],
        ),
        const SizedBox(height: 11),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onTapDown: (d) => _handle(d.localPosition, width),
              onHorizontalDragUpdate: (d) => _handle(d.localPosition, width),
              child: SizedBox(
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 8, left: 0, right: 0,
                      child: Container(height: 8, decoration: BoxDecoration(color: const Color(0xFFE4E3EF), borderRadius: BorderRadius.circular(5))),
                    ),
                    Positioned(
                      top: 8, left: 0,
                      child: Container(
                        width: (pct * width).clamp(0.0, width),
                        height: 8,
                        decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                    Positioned(
                      left: (pct * width - 12).clamp(0.0, width - 24 < 0 ? 0.0 : width - 24),
                      top: 0,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: AppColors.indigo, width: 4),
                          boxShadow: const [BoxShadow(color: Color(0x40141221), blurRadius: 8, offset: Offset(0, 3))],
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

class _PrefToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefToggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!value),
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
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
              IgnorePointer(
                child: CupertinoSwitch(value: value, activeTrackColor: AppColors.indigo, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
