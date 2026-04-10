import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

class SubmitTrickScreen extends StatefulWidget {
  const SubmitTrickScreen({super.key});

  @override
  State<SubmitTrickScreen> createState() => _SubmitTrickScreenState();
}

class _SubmitTrickScreenState extends State<SubmitTrickScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _abbrevCtrl = TextEditingController();

  double _motion = 1.0;
  int _difficulty = 1;
  int _commonLevel = 5;
  bool _crossOver = false;
  bool _knee = false;

  bool _loading = false;
  String? _error;
  bool _submitted = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrevCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _submitted = false;
    });
    try {
      await ApiClient.instance.submitTrick(
        name: _nameCtrl.text.trim(),
        abbreviation: _abbrevCtrl.text.trim(),
        crossOver: _crossOver,
        knee: _knee,
        motion: _motion,
        difficulty: _difficulty,
        commonLevel: _commonLevel,
      );
      setState(() {
        _submitted = true;
        _nameCtrl.clear();
        _abbrevCtrl.clear();
        _motion = 1.0;
        _difficulty = 1;
        _commonLevel = 5;
        _crossOver = false;
        _knee = false;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit a Trick')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggest a new trick to be added to the library. It will be reviewed by an admin before going live.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _abbrevCtrl,
                decoration: const InputDecoration(labelText: 'Abbreviation', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              Text('Motion: ${_motion.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w500)),
              Slider(
                value: _motion,
                min: 0.5,
                max: 10,
                divisions: 19,
                label: _motion.toStringAsFixed(1),
                onChanged: (v) => setState(() => _motion = v),
              ),
              const SizedBox(height: 8),
              Text('Difficulty: $_difficulty', style: const TextStyle(fontWeight: FontWeight.w500)),
              Slider(
                value: _difficulty.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$_difficulty',
                onChanged: (v) => setState(() => _difficulty = v.round()),
              ),
              const SizedBox(height: 8),
              Text('Common Level: $_commonLevel', style: const TextStyle(fontWeight: FontWeight.w500)),
              Slider(
                value: _commonLevel.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$_commonLevel',
                onChanged: (v) => setState(() => _commonLevel = v.round()),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('CrossOver'),
                value: _crossOver,
                onChanged: (v) => setState(() => _crossOver = v),
              ),
              SwitchListTile(
                title: const Text('Knee'),
                value: _knee,
                onChanged: (v) => setState(() => _knee = v),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              if (_submitted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Trick submitted! It will be reviewed by an admin.',
                    style: TextStyle(color: Colors.green[700]),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Trick'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
