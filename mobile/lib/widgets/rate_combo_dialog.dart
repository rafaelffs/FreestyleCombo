import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api/api_client.dart';
import '../theme/app_colors.dart';

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Rate this combo', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select a score from 1 to 5',
            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _score = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    star <= _score ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.star,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.indigo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: (_loading || _score == 0) ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Submit', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
