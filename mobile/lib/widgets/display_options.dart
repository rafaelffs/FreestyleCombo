import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'combo_card.dart' show TrickNameDisplay;
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
    ],
  );
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
