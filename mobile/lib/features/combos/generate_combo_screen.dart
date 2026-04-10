import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/models/combo.dart';
import '../../widgets/combo_card.dart';

class GenerateComboScreen extends StatefulWidget {
  const GenerateComboScreen({super.key});

  @override
  State<GenerateComboScreen> createState() => _GenerateComboScreenState();
}

class _GenerateComboScreenState extends State<GenerateComboScreen> {
  bool _usePrefs = false;
  int _comboLength = 5;
  int _maxDifficulty = 10;
  int _strongFootPct = 50;
  int _noTouchPct = 30;
  int _maxConsecNoTouch = 2;
  bool _includeCrossOver = true;
  bool _includeKnee = true;

  bool _loading = false;
  String? _error;
  ComboDto? _result;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
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
      final combo =
          await ApiClient.instance.generateCombo(_usePrefs, overrides);
      setState(() => _result = combo);
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Combo')),
      body: SingleChildScrollView(
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
                    Text('Options',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Use saved preferences'),
                      value: _usePrefs,
                      onChanged: (v) => setState(() => _usePrefs = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (!_usePrefs) ...[
                      const Divider(),
                      _SliderRow(
                        label: 'Combo length: $_comboLength',
                        value: _comboLength.toDouble(),
                        min: 1,
                        max: 20,
                        divisions: 19,
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
                        max: 10,
                        divisions: 10,
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
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_loading ? 'Generating…' : 'Generate Combo'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 24),
              Text('Result',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ComboCard(combo: _result!, showActions: true),
            ],
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
