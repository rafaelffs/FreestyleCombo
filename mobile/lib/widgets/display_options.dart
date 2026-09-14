import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'combo_card.dart' show TrickNameDisplay, ComboNameDisplay, ComboNameDisplayMode;
import 'difficulty_chip.dart';

/// "Display" section (trick-name format + difficulty show/hide) shared by
/// the Tricks and Combos list screens' settings sheets — a single place so
/// the two lists' toggles can't drift out of sync in behavior or styling.
/// [onChanged] should call the sheet's own `setState`/`StatefulBuilder`
/// setter so the sheet reflects the new value immediately.
Widget buildDisplayOptionsSection({required VoidCallback onChanged}) {
  return Column(
    children: [
      DisplayOptionRow(
        label: 'Trick names',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentButton(
              label: 'Full name',
              active: TrickNameDisplay.showFullName,
              onTap: () {
                TrickNameDisplay.showFullName = true;
                onChanged();
              },
            ),
            const SizedBox(width: 6),
            SegmentButton(
              label: 'Abbr.',
              active: !TrickNameDisplay.showFullName,
              onTap: () {
                TrickNameDisplay.showFullName = false;
                onChanged();
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      DisplayOptionRow(
        label: 'Show difficulty',
        child: CupertinoSwitch(
          value: DifficultyDisplay.show,
          activeTrackColor: AppColors.indigo,
          onChanged: (v) {
            DifficultyDisplay.show = v;
            onChanged();
          },
        ),
      ),
      const SizedBox(height: 12),
      DisplayOptionRow(
        label: 'Combo name',
        child: _ComboNameDropdown(onChanged: onChanged),
      ),
    ],
  );
}

const _kComboNameDisplayLabels = {
  ComboNameDisplayMode.show: 'Show',
  ComboNameDisplayMode.hideUnnamed: 'Hide unnamed',
  ComboNameDisplayMode.hideAlways: 'Hide always',
};

/// A compact dropdown for the 3-way combo-name display mode — a row of
/// SegmentButtons (as used for Trick names above) was tried first, but
/// "Hide unnamed" made a 3-chip row wide enough to need horizontal
/// scrolling next to a label, which read awkwardly for a settings row.
/// `PopupMenuButton` (the same widget already used for row actions in
/// `admin_users_screen.dart`) rather than `DropdownButton` — the latter
/// silently ate every tap in this settings-sheet context (a bare
/// `DropdownButton` needs to indirectly find a `Navigator`/`Overlay` via
/// context the way `showMenu`-based widgets don't rely on quite the same
/// way; every other control in this same sheet responded fine, isolating
/// it to that widget specifically) while `PopupMenuButton` opens reliably.
class _ComboNameDropdown extends StatelessWidget {
  final VoidCallback onChanged;
  const _ComboNameDropdown({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ComboNameDisplayMode>(
      initialValue: ComboNameDisplay.mode,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) {
        ComboNameDisplay.mode = v;
        onChanged();
      },
      itemBuilder: (context) => [
        for (final entry in _kComboNameDisplayLabels.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 6, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _kComboNameDisplayLabels[ComboNameDisplay.mode]!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: AppColors.ink2),
          ],
        ),
      ),
    );
  }
}

class DisplayOptionRow extends StatelessWidget {
  final String label;
  final Widget child;

  const DisplayOptionRow({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
        ),
        child,
      ],
    );
  }
}

class SegmentButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const SegmentButton({super.key, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.indigo : AppColors.chipBg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}
