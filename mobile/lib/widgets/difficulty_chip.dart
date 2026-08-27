import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Small mono-numeral difficulty pill: green (1–4), amber (5–7), red (8–10).
class DifficultyChip extends StatelessWidget {
  final int difficulty;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const DifficultyChip(
    this.difficulty, {
    super.key,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
  });

  static Color backgroundFor(int d) {
    if (d <= 4) return AppColors.greenBg;
    if (d <= 7) return AppColors.amberBg;
    return AppColors.redBg;
  }

  static Color foregroundFor(int d) {
    if (d <= 4) return AppColors.green;
    if (d <= 7) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundFor(difficulty),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$difficulty',
        style: GoogleFonts.jetBrainsMono(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: foregroundFor(difficulty),
          height: 1,
        ),
      ),
    );
  }
}
