import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/prefs/foot_orientation.dart';
import '../theme/app_colors.dart';

/// WF/switch/SF strong-foot indicator — mirrors web's `FootToggle`
/// (web/src/components/ui/foot-toggle.tsx), used only in the "add trick to
/// combo" sheet (create_combo_screen.dart) as the sole focus of that screen.
/// Every other trick-slot surface (sequence lists, build/edit slot rows)
/// intentionally uses a plain compact "WF"/"SF" square instead — this wider
/// switch control doesn't fit those denser rows. The knob icon is
/// `LucideIcons.footprints`, the exact same icon web uses (lucide-react's
/// `Footprints`) — it reads as two feet rather than one, but that's what web
/// itself renders too, so this is matching parity, not a compromise.
/// [scale] multiplies every dimension — pass a larger value (e.g. 1.9) to
/// make the control clearly the sheet's focal point. Which side shows WF vs
/// SF is controlled by [FootOrientation] (Profile → "My strong foot"). The
/// knob is taller than the track and rides a white ring + shadow, so it
/// visually pops in front of the track and overflows its top/bottom edge —
/// the same "floating disc, borders outside the bar" treatment as the
/// bottom-nav Generate FAB in design/mobile-redesign/mocks.html
/// (`.fab{margin-top:-14px;border:3px solid #fff}`).
class FootToggle extends StatelessWidget {
  final bool value; // true = SF (strong foot), false = WF (weak foot)
  final VoidCallback? onTap;
  final double scale;

  const FootToggle({super.key, required this.value, this.onTap, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final trackW = 28.0 * scale;
    final trackH = 14.0 * scale;
    final knob = 20.0 * scale;
    final footSize = 13.0 * scale;
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
                  border: Border.all(color: Colors.white, width: 2.2 * scale),
                  boxShadow: [
                    BoxShadow(
                      color: (value ? AppColors.indigo : AppColors.muted).withValues(alpha: 0.45),
                      blurRadius: 6 * scale,
                      offset: Offset(0, 2 * scale),
                    ),
                  ],
                ),
                child: Icon(LucideIcons.footprints, size: footSize, color: Colors.white),
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
