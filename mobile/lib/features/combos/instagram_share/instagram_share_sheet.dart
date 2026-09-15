import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/combo.dart';
import '../../../core/models/instagram_overlay_content.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/combo_slot_tile.dart';
import 'combo_slot_editor.dart';
import 'instagram_overlay.dart';
import 'instagram_share_service.dart';

/// [combo] is null when opened from the new toolbar icon on the Combos/
/// Tricks pages (no existing combo to share yet). In that case there's
/// nothing to preview until the user actually builds a trick list, so this
/// pushes the full-screen [showComboSlotEditorScreen] first — the Share
/// Image sheet itself only ever opens with a real (if synthetic,
/// never-persisted) combo. Backing out of that editor without adding
/// anything (result null) means there's nothing to share, so the sheet
/// never opens at all. Passing an existing combo (the per-combo share flow)
/// skips straight to the sheet, as before.
Future<void> showInstagramShareSheet(BuildContext context,
    [ComboDto? combo]) async {
  if (combo == null) {
    final built = await showComboSlotEditorScreen(context,
        initialName: '', initialSlots: const []);
    if (built == null || !context.mounted) return;
    combo = built;
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InstagramShareSheet(combo: combo!),
  );
}

List<SlotItem> _slotsFromComboTricks(List<ComboTrickDto>? tricks) {
  final slots = <SlotItem>[];
  for (final t in tricks ?? const <ComboTrickDto>[]) {
    if (t.type == 'combo') {
      slots.add(SlotItem.combo(
        subComboId: t.subComboId!,
        subComboName: t.subComboName ?? '',
        subComboTricks: t.subComboTricks ?? [],
        position: t.position,
      )..strongFoot = t.strongFoot);
    } else {
      slots.add(SlotItem.trick(
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
  return slots;
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

  // The combo actually rendered/exported — starts as widget.combo and gets
  // swapped for whatever the full-screen trick editor returns once the user
  // taps Done there. Never saved anywhere; purely drives this preview/export.
  late ComboDto _liveCombo = widget.combo;

  bool get _nameDisabled => overlayNameToggleDisabled(_liveCombo);
  bool get _sequenceForced => overlaySequenceForced(_liveCombo);

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
            // The preview used to be pinned outside this list (a fix for a
            // real image-capture bug — see instagram_share_service.dart's
            // doc comment — from when the inline SELECT COMBO/TRICK editor
            // made this list tall enough to scroll the preview's
            // RepaintBoundary off-screen). That editor is now its own
            // full-screen route (combo_slot_editor.dart), so this list is
            // short again and the preview never scrolls far enough to be at
            // risk — pinning it back here just meant a swipe starting over
            // the image did nothing (it wasn't part of any Scrollable), a
            // dead zone right where people naturally put their thumb. Back
            // to one plain scrollable list, image included.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line2,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Share Image',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink),
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
                      combo: _liveCombo,
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
            _toggleRow(
                'Combo name',
                _nameDisabled ? false : _toggles.name,
                _nameDisabled,
                (v) => setState(() => _toggles = _toggles.copyWith(name: v))),
            _toggleRow(
                'Difficulty',
                _toggles.difficulty,
                false,
                (v) => setState(
                    () => _toggles = _toggles.copyWith(difficulty: v))),
            _toggleRow(
                'Trick count',
                _toggles.quantity,
                false,
                (v) =>
                    setState(() => _toggles = _toggles.copyWith(quantity: v))),
            _toggleRow('Rating', _toggles.rating, false,
                (v) => setState(() => _toggles = _toggles.copyWith(rating: v))),
            _toggleRow(
                'Trick sequence',
                _sequenceForced || _toggles.sequence,
                _sequenceForced,
                (v) =>
                    setState(() => _toggles = _toggles.copyWith(sequence: v))),
            const SizedBox(height: 22),
            Text('SELECT COMBO/TRICK', style: _sectionLabelStyle),
            const SizedBox(height: 10),
            _comboSummaryRow(),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.red, fontSize: 13)),
              ),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saving ? null : _saveImage,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Save to device',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.white),
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

  // Chips keep their natural compact size (like the original Wrap did —
  // forcing them into equal-width Expanded slots made differently-sized
  // chips look centered with uneven gaps between them, which read as
  // "ugly"/inconsistent). Wrapped in a horizontal scroll instead of Wrap
  // so a row that doesn't fit (e.g. Text Size's 4 chips including the long
  // "Smallest" label) scrolls sideways rather than breaking to a second
  // line — on most devices it still fits and there's nothing to scroll.
  Widget _chipRow<T>(
      List<(T, String)> options, T selected, ValueChanged<T> onSelected) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in options) ...[
            if (value != options.first.$1) const SizedBox(width: 8),
            ChoiceChip(
              label: Text(label),
              selected: selected == value,
              onSelected: (_) => onSelected(value),
              selectedColor: AppColors.indigoTint,
              backgroundColor: AppColors.surface,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected == value ? AppColors.indigo : AppColors.ink2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                    color:
                        selected == value ? AppColors.indigo : AppColors.line2),
              ),
            ),
          ],
        ],
      ),
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

  Widget _toggleRow(
      String label, bool value, bool disabled, ValueChanged<bool> onChanged) {
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

  Widget _comboSummaryRow() {
    final count = _liveCombo.tricks?.length ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _editTricks,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          border: Border.all(color: AppColors.line2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_outlined, size: 18, color: AppColors.indigo),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                count == 0
                    ? 'Edit tricks'
                    : '$count trick${count == 1 ? '' : 's'} selected — tap to edit',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink2),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.faint),
          ],
        ),
      ),
    );
  }

  Future<void> _editTricks() async {
    final result = await showComboSlotEditorScreen(
      context,
      initialName: _liveCombo.name ?? '',
      initialSlots: _slotsFromComboTricks(_liveCombo.tricks),
    );
    if (result != null && mounted) setState(() => _liveCombo = result);
  }

  Future<void> _saveImage() async {
    // Capture before any setState — see InstagramShareService's doc comment
    // for why: flipping the button into its spinner state first would
    // rebuild this whole sheet (including the preview) right before the
    // capture, racing RenderRepaintBoundary.toImage()'s requirement that
    // the render object already be freshly painted.
    final Uint8List pngBytes;
    try {
      pngBytes = await InstagramShareService.capturePng(_boundaryKey,
          pixelRatio: kInstagramOverlayExportPixelRatio);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await InstagramShareService.saveBytes(pngBytes);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved to Photos')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
