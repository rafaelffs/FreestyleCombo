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
/// badge is a sibling of the track inside a [Stack], not a child laid out
/// inside it — its size is unrelated to the track's own height, and paint
/// order (badge added after the track) is what puts it visually in front,
/// riding above the track's top/bottom edge as it slides between sides.
class FootToggle extends StatelessWidget {
  final bool value; // true = SF (strong foot), false = WF (weak foot)
  final VoidCallback? onTap;
  final double scale;

  const FootToggle({super.key, required this.value, this.onTap, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final trackW = 34.0 * scale;
    final trackH = 16.0 * scale;
    final badge = 20.0 * scale;
    final footSize = 12.0 * scale;
    final fontSize = 10.0 * scale;
    final gap = 4.0 * scale;
    final radius = 8.0 * scale;

    final leftIsStrong = !FootOrientation.strongFootIsRight;
    // The badge sits on the "strong" side when value is true (SF), the
    // "weak" side otherwise — which physical side that is depends on
    // orientation. Flush with the track's own left/right edge (not
    // overshooting past it) so it never overlaps the WF/SF labels.
    final badgeOnLeft = value ? leftIsStrong : !leftIsStrong;
    final badgeLeft = badgeOnLeft ? 0.0 : trackW - badge;

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
          SizedBox(
            width: trackW,
            height: badge,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: (badge - trackH) / 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: trackH,
                    decoration: BoxDecoration(
                      color: value ? AppColors.indigoTint : AppColors.chipBg,
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(color: value ? const Color(0xFFC7CCF7) : AppColors.line2),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  left: badgeLeft,
                  top: 0,
                  child: Container(
                    width: badge,
                    height: badge,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value ? AppColors.indigo : AppColors.muted,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (value ? AppColors.indigo : AppColors.muted).withValues(alpha: 0.35),
                          blurRadius: 5 * scale,
                          offset: Offset(0, 2 * scale),
                        ),
                      ],
                    ),
                    child: Icon(LucideIcons.footprints, size: footSize, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: gap),
          label(leftIsStrong ? 'WF' : 'SF', !leftIsStrong),
        ],
      ),
    );
  }
}
