import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/prefs/foot_orientation.dart';
import '../theme/app_colors.dart';

/// WF/switch/SF strong-foot indicator — mirrors web's `FootToggle`
/// (web/src/components/ui/foot-toggle.tsx), used only in the "add trick to
/// combo" sheet (create_combo_screen.dart) as the sole focus of that screen.
/// Every other trick-slot surface (sequence lists, build/edit slot rows)
/// intentionally uses a plain compact "WF"/"SF" square instead — this wider
/// switch control doesn't fit those denser rows. No icon in the knob: after
/// a few failed attempts at a recognizable single-foot glyph (two-foot
/// pictograms, disconnected-blob composition, a shape that read as a
/// pointer/cursor), a plain colored knob reads unambiguously and needs no
/// icon to convey state — the WF/SF labels already do that.
/// [scale] multiplies every dimension — pass a larger value (e.g. 1.9) to
/// make the control clearly the sheet's focal point. Which side shows WF vs
/// SF is controlled by [FootOrientation] (Profile → "My strong foot").
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
                decoration: BoxDecoration(
                  color: value ? AppColors.indigo : AppColors.muted,
                  shape: BoxShape.circle,
                ),
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
