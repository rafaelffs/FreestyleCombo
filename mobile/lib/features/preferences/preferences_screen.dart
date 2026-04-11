import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user_preference.dart';
import 'package:go_router/go_router.dart';

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

  void _logout() {
    AuthService.instance.clear();
    context.go('/public');
  }

  void _openForm({UserPreference? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
        title: const Text('Delete preference'),
        content: Text('Delete "${pref.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
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
      appBar: AppBar(
        title: const Text('Preferences'),
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _prefs.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(child: Text('No preferences saved yet.\nTap + to create one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _prefs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _PrefCard(
                            pref: _prefs[i],
                            onEdit: () => _openForm(existing: _prefs[i]),
                            onDelete: () => _delete(_prefs[i]),
                          ),
                        ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
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
    final stats = 'Length ${pref.comboLength} · Diff ≤${pref.maxDifficulty} · SF ${pref.strongFootPercentage}% · NT ${pref.noTouchPercentage}%';
    final flags = '${pref.includeCrossOver ? "CO ✓" : "CO ✗"} · ${pref.includeKnee ? "Knee ✓" : "Knee ✗"} · Max consec NT ${pref.maxConsecutiveNoTouch}';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(pref.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(stats, style: const TextStyle(fontSize: 12)),
            Text(flags, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit, tooltip: 'Edit'),
            IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: onDelete, tooltip: 'Delete'),
          ],
        ),
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
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? 'Edit preference' : 'New preference',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g. NT Combinations',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _SliderRow(label: 'Combo length: $_comboLength', value: _comboLength.toDouble(), min: 1, max: 100, divisions: 99, onChanged: (v) => setState(() => _comboLength = v.round())),
                    _SliderRow(label: 'Max difficulty: $_maxDifficulty', value: _maxDifficulty.toDouble(), min: 1, max: 10, divisions: 9, onChanged: (v) => setState(() => _maxDifficulty = v.round())),
                    _SliderRow(label: 'Strong foot: $_strongFootPct%', value: _strongFootPct.toDouble(), min: 0, max: 100, divisions: 10, onChanged: (v) => setState(() => _strongFootPct = v.round())),
                    _SliderRow(label: 'No-touch: $_noTouchPct%', value: _noTouchPct.toDouble(), min: 0, max: 100, divisions: 10, onChanged: (v) => setState(() => _noTouchPct = v.round())),
                    _SliderRow(label: 'Max consecutive NT: $_maxConsecNoTouch', value: _maxConsecNoTouch.toDouble(), min: 0, max: 30, divisions: 30, onChanged: (v) => setState(() => _maxConsecNoTouch = v.round())),
                    SwitchListTile(title: const Text('Include crossover'), value: _includeCrossOver, onChanged: (v) => setState(() => _includeCrossOver = v), contentPadding: EdgeInsets.zero),
                    SwitchListTile(title: const Text('Include knee'), value: _includeKnee, onChanged: (v) => setState(() => _includeKnee = v), contentPadding: EdgeInsets.zero),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Save changes' : 'Create preference'),
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

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

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
