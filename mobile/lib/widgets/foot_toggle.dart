import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../core/prefs/foot_orientation.dart';
import '../theme/app_colors.dart';

/// WF/switch/SF strong-foot indicator — mirrors web's `FootToggle`
/// (web/src/components/ui/foot-toggle.tsx) so the same visual shows up
/// everywhere a trick slot's foot is shown or set: combo sequence lists and
/// the build/edit screens' slot rows. Pass [onTap] to make it interactive
/// (build/edit slots); omit it for a read-only display (sequence lists).
/// [scale] multiplies every dimension — use a larger value (e.g. 2.2) where
/// this is the sole focus of a screen (the add-trick sheet); the default 1.0
/// is sized for sitting inline in a dense row. Which side shows WF vs SF is
/// controlled by [FootOrientation] (Profile → "My strong foot"), not fixed.
class FootToggle extends StatelessWidget {
  final bool value; // true = SF (strong foot), false = WF (weak foot)
  final VoidCallback? onTap;
  final double scale;

  const FootToggle({super.key, required this.value, this.onTap, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final trackW = 28.0 * scale;
    final trackH = 14.0 * scale;
    final knob = 12.0 * scale;
    final footSize = 8.0 * scale;
    final fontSize = 10.0 * scale;
    final gap = 4.0 * scale;
    final radius = 7.0 * scale;

    final leftIsStrong = !FootOrientation.strongFootIsRight;
    // The knob sits on the "strong" side when value is true (SF), the "weak"
    // side otherwise — which physical side that is depends on orientation.
    final knobOnLeft = value ? leftIsStrong : !leftIsStrong;

    Widget label(String text, bool isStrong) {
      final active = isStrong == value;
      return Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.indigo : AppColors.faint,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          label(leftIsStrong ? 'SF' : 'WF', leftIsStrong),
          SizedBox(width: gap),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: trackW,
            height: trackH,
            padding: EdgeInsets.all(scale),
            decoration: BoxDecoration(
              color: value ? AppColors.indigoTint : AppColors.chipBg,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: value ? const Color(0xFFC7CCF7) : AppColors.line2),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              alignment: knobOnLeft ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: knob,
                height: knob,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value ? AppColors.indigo : AppColors.muted,
                  shape: BoxShape.circle,
                ),
                child: Icon(Symbols.footprint, size: footSize, color: Colors.white),
              ),
            ),
          ),
          SizedBox(width: gap),
          label(leftIsStrong ? 'WF' : 'SF', !leftIsStrong),
        ],
      ),
    );
  }
}
