import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/combo.dart';
import '../../../theme/app_colors.dart';
import 'instagram_share_sheet.dart';

/// Shows the "Share to Social Media" vs. "Share Link" choice — the existing
/// share icon opens this instead of firing Share.share directly.
/// [onShareLink] runs the existing link-share flow unchanged; the social
/// option opens the style/stats picker (instagram_share_sheet.dart) to build
/// a shareable image, saved to the device (see the "Add to Story" removal —
/// Instagram's sticker-share API can't layer onto a video the user picks
/// afterward, since it opens a blank canvas rather than a media picker).
Future<void> showShareOptionsSheet(
  BuildContext context, {
  required ComboDto combo,
  required VoidCallback onShareLink,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Share "${combo.name ?? combo.displayText}"',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.faint,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ShareOptionTile(
            iconGradient: const LinearGradient(
              colors: [Color(0xFFFEDA75), Color(0xFFD62976), Color(0xFF4F5BD5)],
            ),
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
            title: 'Share to Social Media',
            subtitle: 'Create a shareable image',
            onTap: () {
              Navigator.pop(sheetContext);
              showInstagramShareSheet(context, combo);
            },
          ),
          _ShareOptionTile(
            iconBackground: AppColors.indigoTint,
            icon: const Icon(Icons.link, color: AppColors.indigo),
            title: 'Share Link',
            subtitle: 'Copy or send the combo page',
            onTap: () {
              Navigator.pop(sheetContext);
              onShareLink();
            },
          ),
        ],
      ),
    ),
  );
}

class _ShareOptionTile extends StatelessWidget {
  final Color? iconBackground;
  final Gradient? iconGradient;
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOptionTile({
    this.iconBackground,
    this.iconGradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBackground,
                gradient: iconGradient,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
