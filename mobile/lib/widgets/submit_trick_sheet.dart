import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api/api_client.dart';
import '../theme/app_colors.dart';

Future<void> showSubmitTrickSheet(
  BuildContext context, {
  String? initialName,
  required VoidCallback onSubmitted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => SubmitTrickForm(initialName: initialName, onSubmitted: onSubmitted),
  );
}

class SubmitTrickForm extends StatefulWidget {
  final VoidCallback onSubmitted;
  final String? initialName;
  const SubmitTrickForm({super.key, required this.onSubmitted, this.initialName});

  @override
  State<SubmitTrickForm> createState() => _SubmitTrickFormState();
}

class _SubmitTrickFormState extends State<SubmitTrickForm> {
  late final _nameCtrl = TextEditingController(text: widget.initialName ?? '');
  final _abbrevCtrl = TextEditingController();
  double _revolution = 1;
  int _difficulty = 1;
  int _commonLevel = 5;
  bool _crossOver = false;
  bool _knee = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrevCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _abbrevCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name and abbreviation are required.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.submitTrick(
        name: _nameCtrl.text.trim(),
        abbreviation: _abbrevCtrl.text.trim(),
        crossOver: _crossOver,
        knee: _knee,
        revolution: _revolution,
        difficulty: _difficulty,
        commonLevel: _commonLevel,
      );
      if (mounted) widget.onSubmitted();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 16, 22, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Text('Submit a trick', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: _SubmitField(
                  controller: _abbrevCtrl,
                  label: 'Abbreviation',
                  hint: 'e.g. CO',
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SubmitField(
                  controller: _nameCtrl,
                  label: 'Name',
                  hint: 'e.g. Crossover',
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SubmitSlider(
            label: 'Revolutions',
            value: _revolution,
            min: 0.5,
            max: 4,
            formatValue: (v) => v.toStringAsFixed(1),
            onChanged: (v) => setState(() => _revolution = (v * 2).round() / 2),
          ),
          const SizedBox(height: 18),
          _SubmitSlider(
            label: 'Difficulty',
            value: _difficulty.toDouble(),
            min: 1,
            max: 10,
            onChanged: (v) => setState(() => _difficulty = v.round()),
          ),
          const SizedBox(height: 18),
          SubmitToggle(label: 'Cross-over', value: _crossOver, onChanged: (v) => setState(() => _crossOver = v)),
          const SizedBox(height: 11),
          SubmitToggle(label: 'Knee trick', value: _knee, onChanged: (v) => setState(() => _knee = v)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _SubmitField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextCapitalization textCapitalization;

  const _SubmitField({required this.controller, required this.label, required this.hint, required this.textCapitalization});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      autocorrect: false,
      enableSuggestions: false,
      style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.chipBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
      ),
    );
  }
}

class _SubmitSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double)? formatValue;

  const _SubmitSlider({
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

class SubmitToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SubmitToggle({required this.label, required this.value, required this.onChanged});

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
