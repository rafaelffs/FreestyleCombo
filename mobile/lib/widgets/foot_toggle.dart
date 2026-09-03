import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// WF/switch/SF strong-foot indicator — mirrors web's `FootToggle`
/// (web/src/components/ui/foot-toggle.tsx) so the same visual shows up
/// everywhere a trick slot's foot is shown or set: combo sequence lists and
/// the build/edit screens' slot rows. Pass [onTap] to make it interactive
/// (build/edit slots); omit it for a read-only display (sequence lists).
class FootToggle extends StatelessWidget {
  final bool value; // true = SF (strong foot), false = WF (weak foot)
  final VoidCallback? onTap;

  const FootToggle({super.key, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'WF',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: value ? AppColors.faint : AppColors.indigo,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 14,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: value ? AppColors.indigoTint : AppColors.chipBg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: value ? const Color(0xFFC7CCF7) : AppColors.line2),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: value ? AppColors.indigo : AppColors.muted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_walk, size: 8, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'SF',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: value ? AppColors.indigo : AppColors.faint,
            ),
          ),
        ],
      ),
    );
  }
}
