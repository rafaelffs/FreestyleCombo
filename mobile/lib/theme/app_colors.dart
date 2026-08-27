import 'package:flutter/material.dart';

/// Design tokens for the FreestyleCombo mobile redesign.
/// See design/mobile-redesign/design_spec.md for the visual reference.
class AppColors {
  AppColors._();

  static const indigo = Color(0xFF4F46E5);
  static const indigoD = Color(0xFF3F37C9);
  static const violet = Color(0xFF7A5AF0);
  static const lime = Color(0xFFC6F135); // energy accent — generate / highlights
  static const limeText = Color(0xFF26310A);

  static const ink = Color(0xFF15131F); // primary text
  static const ink2 = Color(0xFF3A3752);
  static const muted = Color(0xFF7C7A93);
  static const faint = Color(0xFFA9A7BC);

  static const bg = Color(0xFFF4F4F9); // screen background
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFECEBF3);
  static const line2 = Color(0xFFE3E2EE);

  // difficulty scale
  static const green = Color(0xFF16A34A);
  static const greenBg = Color(0xFFDCFCE7); // 1–4
  static const amber = Color(0xFFB45309);
  static const amberBg = Color(0xFFFEF3C7); // 5–7
  static const red = Color(0xFFDC2626);
  static const redBg = Color(0xFFFEE2E2); // 8–10

  // accents used across cards (favourite / rating / no-touch tint)
  static const pink = Color(0xFFEC4899);
  static const star = Color(0xFFF59E0B);
  static const noTouchBg = Color(0xFFEDE9FE);
  static const noTouchText = Color(0xFF6D28D9);

  // neutral / indigo-tinted tile backgrounds (trick chips, position tiles, SF tags)
  static const chipBg = Color(0xFFF1F0F8);
  static const indigoTint = Color(0xFFEEF0FE);

  static const grad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B4FE9), Color(0xFF7A5AF0), Color(0xFF8E6BF5)],
  );
}
