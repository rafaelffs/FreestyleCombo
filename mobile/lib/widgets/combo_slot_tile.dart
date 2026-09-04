import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models/combo.dart';
import '../theme/app_colors.dart';

/// One slot in a combo's trick sequence, shared by the manual build/generate
/// screen and the inline "edit combo" screen so the two never drift apart —
/// see git history for two separate bugs (transition-trick SF/NT handling,
/// then first-slot no-touch) that came from these being hand-duplicated.
class SlotItem {
  // For a trick slot
  final String? trickId;
  final String? trickName;
  final String? abbreviation;
  bool crossOver;
  final bool isTransition;

  // For a sub-combo slot
  final String? subComboId;
  final String? subComboName;
  final List<ComboTrickDto>? subComboTricks;

  bool get isSubCombo => subComboId != null;

  // Matches the server's actual rule (BuildComboHandler/GenerateComboHandler):
  // a trick can be marked no-touch only if the trick immediately before it
  // is a CrossOver move — not based on the no-touch trick's own CrossOver
  // flag. A transition trick (e.g. "Combo") never enables it for the next
  // slot; a sub-combo slot enables it only if its own last trick is CrossOver.
  bool get allowsNoTouchOnNext {
    if (isTransition) return false;
    if (isSubCombo) {
      final tricks = subComboTricks;
      if (tricks == null || tricks.isEmpty) return false;
      return tricks.last.crossOver;
    }
    return crossOver;
  }

  int position;
  bool strongFoot;
  bool noTouch;
  bool expanded; // for sub-combo expand in slot list

  SlotItem.trick({
    required String trickId,
    required String trickName,
    required String abbreviation,
    required this.crossOver,
    required this.position,
    this.strongFoot = true,
    this.noTouch = false,
    this.isTransition = false,
  })  : trickId = trickId,
        trickName = trickName,
        abbreviation = abbreviation,
        subComboId = null,
        subComboName = null,
        subComboTricks = null,
        expanded = false;

  SlotItem.combo({
    required String subComboId,
    required String subComboName,
    required List<ComboTrickDto> subComboTricks,
    required this.position,
    this.strongFoot = true,
    this.noTouch = false,
  })  : trickId = null,
        trickName = null,
        abbreviation = null,
        crossOver = false,
        isTransition = false,
        subComboId = subComboId,
        subComboName = subComboName,
        subComboTricks = subComboTricks,
        expanded = false;
}

/// Renumbers `slots` positions in place and clears a slot's `noTouch` if
/// reordering/removal put an ineligible trick before it (no-touch is only
/// valid right after a CrossOver trick — see [SlotItem.allowsNoTouchOnNext]).
void renumberSlots(List<SlotItem> slots) {
  for (var i = 0; i < slots.length; i++) {
    slots[i].position = i + 1;
    final allowed = i > 0 && slots[i - 1].allowsNoTouchOnNext;
    if (!slots[i].isSubCombo && !allowed && slots[i].noTouch) {
      slots[i].noTouch = false;
    }
  }
}

/// Regular (non-sub-combo) slot row: drag handle, position, name/abbreviation,
/// WF/NT toggles (skipped for a transition trick), remove button.
class SlotTile extends StatelessWidget {
  final int index;
  final SlotItem slot;
  final bool showAbbrev;
  final bool noTouchAllowed;
  final VoidCallback onRemove;
  final ValueChanged<bool> onToggleStrongFoot;
  final ValueChanged<bool> onToggleNoTouch;

  const SlotTile({
    super.key,
    required this.index,
    required this.slot,
    required this.showAbbrev,
    required this.noTouchAllowed,
    required this.onRemove,
    required this.onToggleStrongFoot,
    required this.onToggleNoTouch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_indicator, size: 18, color: AppColors.faint),
          ),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.indigoTint, borderRadius: BorderRadius.circular(9)),
            child: Text(
              '${slot.position}',
              style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.indigo),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              slot.isTransition ? (slot.abbreviation ?? '') : ((showAbbrev ? slot.abbreviation : slot.trickName) ?? ''),
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // A transition trick (e.g. "Combo") is a connector, not a move —
          // strong/weak foot and no-touch don't apply to it.
          if (!slot.isTransition) ...[
            SlotFlagToggle(
              label: 'WF',
              active: !slot.strongFoot,
              onTap: () => onToggleStrongFoot(!slot.strongFoot),
            ),
            SlotFlagToggle(
              label: 'NT',
              active: slot.noTouch,
              enabled: noTouchAllowed,
              onTap: noTouchAllowed ? () => onToggleNoTouch(!slot.noTouch) : null,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Sub-combo slot row: same header shape as [SlotTile] but with a "COMBO"
/// badge instead of WF/NT toggles, and an expandable chip list of the
/// referenced combo's own tricks.
class SubComboSlotTile extends StatelessWidget {
  final int index;
  final SlotItem slot;
  final VoidCallback onRemove;
  final VoidCallback onToggleExpand;

  const SubComboSlotTile({
    super.key,
    required this.index,
    required this.slot,
    required this.onRemove,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.noTouchBg,
        border: Border.all(color: const Color(0xFFE5E0FB)),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_indicator, size: 18, color: AppColors.noTouchText),
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(9)),
                  child: Text(
                    '${slot.position}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.noTouchText),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'COMBO',
                    style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.noTouchText, letterSpacing: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slot.subComboName ?? '',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(slot.expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.noTouchText),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onToggleExpand,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
          if (slot.expanded && slot.subComboTricks != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: slot.subComboTricks!.map((t) {
                  final suffix = t.noTouch ? '·nt' : (!t.strongFoot ? '·wf' : '');
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9)),
                    child: Text(
                      '${t.position}. ${t.abbreviation ?? ''}$suffix',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink2),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small pill toggle used for the WF/NT flags on a [SlotTile].
class SlotFlagToggle extends StatelessWidget {
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  const SlotFlagToggle({super.key, required this.label, required this.active, this.enabled = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.indigoTint : Colors.transparent;
    final fg = !enabled ? AppColors.faint : (active ? AppColors.indigo : AppColors.muted);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
      ),
    );
  }
}
