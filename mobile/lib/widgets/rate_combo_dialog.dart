import 'package:flutter/material.dart';
import '../core/api/api_client.dart';

class RateComboDialog extends StatefulWidget {
  final String comboId;
  final VoidCallback? onRated;

  const RateComboDialog({super.key, required this.comboId, this.onRated});

  @override
  State<RateComboDialog> createState() => _RateComboDialogState();
}

class _RateComboDialogState extends State<RateComboDialog> {
  int _score = 0;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_score == 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.rateCombo(widget.comboId, _score);
      widget.onRated?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate this combo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select a score from 1 to 5'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _score = star),
                child: Icon(
                  star <= _score ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
                ),
              );
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_loading || _score == 0) ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ],
    );
  }
}
