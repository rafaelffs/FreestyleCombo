import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

/// Shared gradient-hero + white-sheet chrome for the Welcome/auth screens
/// (login & register). See design/mobile-redesign/design_spec.md, screen 1.
class AuthScaffold extends StatelessWidget {
  final String headline;
  final String headlineAccent;
  final String subtitle;
  final Widget sheet;

  const AuthScaffold({
    super.key,
    required this.headline,
    required this.headlineAccent,
    required this.subtitle,
    required this.sheet,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Container(
                decoration: const BoxDecoration(gradient: AppColors.grad),
                child: Stack(
                  children: [
                    Positioned(
                      top: -90, right: -110,
                      child: Container(
                        width: 320, height: 320,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lime.withValues(alpha: 0.22)),
                      ),
                    ),
                    Positioned(
                      bottom: 220, left: -120,
                      child: Container(
                        width: 260, height: 260,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.14)),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: context.canPop()
                                      ? _ChromeIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => context.pop())
                                      : _ChromeIconButton(icon: Icons.close, onTap: () => context.go('/combos')),
                                ),
                                const SizedBox(height: 22),
                                Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.sports_soccer, color: Colors.white, size: 32),
                                ),
                                const SizedBox(height: 26),
                                Text.rich(
                                  TextSpan(
                                    style: GoogleFonts.plusJakartaSans(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.0, color: Colors.white),
                                    children: [
                                      TextSpan(text: headline),
                                      TextSpan(text: headlineAccent, style: const TextStyle(color: AppColors.lime)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 300),
                                  child: Text(
                                    subtitle,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85), height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 32),
                            padding: const EdgeInsets.fromLTRB(26, 28, 26, 30),
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(32), bottom: Radius.circular(46)),
                            ),
                            child: sheet,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChromeIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ChromeIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 18, color: Colors.white)),
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      validator: validator,
      style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.chipBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.red)),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const AuthPrimaryButton({super.key, required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onPressed,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.grad,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.violet.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -8),
            ],
          ),
          child: loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
