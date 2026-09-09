import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/combo.dart';
import '../../../core/models/instagram_overlay_content.dart';
import '../../../theme/app_colors.dart';
import 'instagram_overlay.dart';
import 'instagram_share_service.dart';

Future<void> showInstagramShareSheet(BuildContext context, ComboDto combo) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InstagramShareSheet(combo: combo),
  );
}

class _InstagramShareSheet extends StatefulWidget {
  final ComboDto combo;
  const _InstagramShareSheet({required this.combo});

  @override
  State<_InstagramShareSheet> createState() => _InstagramShareSheetState();
}

class _InstagramShareSheetState extends State<_InstagramShareSheet> {
  final _boundaryKey = GlobalKey();
  InstagramOverlayStyle _style = InstagramOverlayStyle.sequence;
  InstagramOverlayPosition _position = InstagramOverlayPosition.bottom;
  InstagramTextSize _textSize = InstagramTextSize.medium;
  InstagramOverlayToggles _toggles = const InstagramOverlayToggles();
  bool _saving = false;
  String? _error;

  bool get _nameDisabled => overlayNameToggleDisabled(widget.combo);
  bool get _sequenceForced => overlaySequenceForced(widget.combo);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollController,
          // Without this, iOS's default overscroll-bounce at the end of the
          // list feeds drag deltas into the DraggableScrollableSheet's own
          // resize handling — so scrolling past the bottom (or top) reads
          // as "drag the sheet down" and closes the whole modal instead of
          // just bouncing in place.
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Share Image',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 20),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5B3A7A), Color(0xFF2C2350)],
                    ),
                  ),
                  // The gradient above is preview-only decoration standing in
                  // for the person's real photo/video — it sits OUTSIDE the
                  // RepaintBoundary, so the actual captured/exported image
                  // (Task 4) stays fully transparent there.
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: InstagramOverlay(
                      combo: widget.combo,
                      style: _style,
                      toggles: _toggles,
                      textSize: _textSize,
                      position: _position,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('LAYOUT', style: _sectionLabelStyle),
            const SizedBox(height: 10),
            _styleRow(),
            const SizedBox(height: 22),
            Text('TEXT SIZE', style: _sectionLabelStyle),
            const SizedBox(height: 10),
            _sizeRow(),
            const SizedBox(height: 22),
            Text('POSITION', style: _sectionLabelStyle),
            const SizedBox(height: 10),
            _positionRow(),
            const SizedBox(height: 22),
            Text('SHOW ON OVERLAY', style: _sectionLabelStyle),
            const SizedBox(height: 10),
            _toggleRow('Combo name', _nameDisabled ? false : _toggles.name, _nameDisabled, (v) => setState(() => _toggles = _toggles.copyWith(name: v))),
            _toggleRow('Difficulty', _toggles.difficulty, false, (v) => setState(() => _toggles = _toggles.copyWith(difficulty: v))),
            _toggleRow('Trick count', _toggles.quantity, false, (v) => setState(() => _toggles = _toggles.copyWith(quantity: v))),
            _toggleRow('Rating', _toggles.rating, false, (v) => setState(() => _toggles = _toggles.copyWith(rating: v))),
            _toggleRow('Trick sequence', _sequenceForced || _toggles.sequence, _sequenceForced, (v) => setState(() => _toggles = _toggles.copyWith(sequence: v))),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
              ),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saving ? null : _saveImage,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Save to device',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _sectionLabelStyle => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.faint,
      );

  // Row + Expanded (not Wrap) so the chips always stay on one line,
  // splitting the available width evenly, regardless of how many options
  // or how long their labels are (e.g. "Smallest" alongside "Small").
  Widget _chipRow<T>(List<(T, String)> options, T selected, ValueChanged<T> onSelected) {
    return Row(
      children: [
        for (final (value, label) in options) ...[
          if (value != options.first.$1) const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: Text(label, overflow: TextOverflow.ellipsis),
              selected: selected == value,
              onSelected: (_) => onSelected(value),
              selectedColor: AppColors.indigoTint,
              backgroundColor: AppColors.surface,
              labelPadding: EdgeInsets.zero,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected == value ? AppColors.indigo : AppColors.ink2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(color: selected == value ? AppColors.indigo : AppColors.line2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _styleRow() {
    return _chipRow<InstagramOverlayStyle>(
      const [
        (InstagramOverlayStyle.minimal, 'Minimal'),
        (InstagramOverlayStyle.sequence, 'Sequence'),
        (InstagramOverlayStyle.stat, 'Stat'),
      ],
      _style,
      (v) => setState(() => _style = v),
    );
  }

  Widget _positionRow() {
    return _chipRow<InstagramOverlayPosition>(
      const [
        (InstagramOverlayPosition.top, 'Top'),
        (InstagramOverlayPosition.bottom, 'Bottom'),
      ],
      _position,
      (v) => setState(() => _position = v),
    );
  }

  Widget _sizeRow() {
    return _chipRow<InstagramTextSize>(
      const [
        (InstagramTextSize.smallest, 'Smallest'),
        (InstagramTextSize.small, 'Small'),
        (InstagramTextSize.medium, 'Medium'),
        (InstagramTextSize.large, 'Large'),
      ],
      _textSize,
      (v) => setState(() => _textSize = v),
    );
  }

  Widget _toggleRow(String label, bool value, bool disabled, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: disabled ? AppColors.faint : AppColors.ink2,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppColors.indigo,
            onChanged: disabled ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _saveImage() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await InstagramShareService.saveImage(_boundaryKey, pixelRatio: kInstagramOverlayExportPixelRatio);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Photos')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
