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
  UserPreference? _pref;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _successMessage;

  // Editable state
  int _comboLength = 5;
  int _maxDifficulty = 10;
  int _strongFootPct = 50;
  int _noTouchPct = 30;
  int _maxConsecNoTouch = 2;
  bool _includeCrossOver = true;
  bool _includeKnee = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pref = await ApiClient.instance.getPreferences();
      if (pref != null) {
        _pref = pref;
        _comboLength = pref.comboLength;
        _maxDifficulty = pref.maxDifficulty;
        _strongFootPct = pref.strongFootPercentage;
        _noTouchPct = pref.noTouchPercentage;
        _maxConsecNoTouch = pref.maxConsecutiveNoTouch;
        _includeCrossOver = pref.includeCrossOver;
        _includeKnee = pref.includeKnee;
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final updated = UserPreference(
        id: _pref?.id ?? '',
        userId: _pref?.userId ?? AuthService.instance.userId ?? '',
        comboLength: _comboLength,
        maxDifficulty: _maxDifficulty,
        strongFootPercentage: _strongFootPct,
        noTouchPercentage: _noTouchPct,
        maxConsecutiveNoTouch: _maxConsecNoTouch,
        includeCrossOver: _includeCrossOver,
        includeKnee: _includeKnee,
        allowedRevolutions: _pref?.allowedRevolutions ?? [],
      );
      _pref = await ApiClient.instance.upsertPreferences(updated);
      setState(() => _successMessage = 'Preferences saved!');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _logout() {
    AuthService.instance.clear();
    context.go('/public');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Default Combo Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Used when generating with "Use saved preferences".',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SliderRow(
                      label: 'Combo length: $_comboLength',
                      value: _comboLength.toDouble(),
                      min: 1,
                      max: 100,
                      divisions: 99,
                      onChanged: (v) =>
                          setState(() => _comboLength = v.round()),
                    ),
                    _SliderRow(
                      label: 'Max difficulty: $_maxDifficulty',
                      value: _maxDifficulty.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: (v) =>
                          setState(() => _maxDifficulty = v.round()),
                    ),
                    _SliderRow(
                      label: 'Strong foot: $_strongFootPct%',
                      value: _strongFootPct.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 10,
                      onChanged: (v) =>
                          setState(() => _strongFootPct = v.round()),
                    ),
                    _SliderRow(
                      label: 'No-touch: $_noTouchPct%',
                      value: _noTouchPct.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 10,
                      onChanged: (v) =>
                          setState(() => _noTouchPct = v.round()),
                    ),
                    _SliderRow(
                      label: 'Max consecutive NT: $_maxConsecNoTouch',
                      value: _maxConsecNoTouch.toDouble(),
                      min: 0,
                      max: 30,
                      divisions: 30,
                      onChanged: (v) =>
                          setState(() => _maxConsecNoTouch = v.round()),
                    ),
                    SwitchListTile(
                      title: const Text('Include crossover'),
                      value: _includeCrossOver,
                      onChanged: (v) =>
                          setState(() => _includeCrossOver = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Include knee'),
                      value: _includeKnee,
                      onChanged: (v) => setState(() => _includeKnee = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 12),
              Text(_successMessage!,
                  style: const TextStyle(color: Colors.green)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save preferences'),
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
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
