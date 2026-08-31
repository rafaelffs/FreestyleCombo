import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';
import '../../theme/app_colors.dart';
import 'auth_chrome.dart';
import 'social_sign_in_buttons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _credentialCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _credentialCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSignedIn() async {
    final pending = AuthService.instance.getPendingCombo();
    if (pending != null) {
      try {
        final tricks = (pending['tricks'] as List).map((t) => BuildComboTrickItem(
          trickId: t['trickId'] as String,
          position: t['position'] as int,
          strongFoot: t['strongFoot'] as bool,
          noTouch: t['noTouch'] as bool,
        )).toList();
        await ApiClient.instance.buildCombo(tricks, pending['isPublic'] as bool, name: pending['name'] as String?);
      } finally {
        await AuthService.instance.clearPendingCombo();
      }
    }
    if (mounted) context.go('/combos');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiClient.instance
          .login(_credentialCtrl.text.trim(), _passwordCtrl.text);
      await AuthService.instance.setCredentials(result.token, result.userId);
      await _onSignedIn();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      headline: 'Master your\nnext ',
      headlineAccent: 'combo.',
      subtitle: 'Generate, build and track freestyle football combos. Level up, one trick at a time.',
      sheet: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              controller: _credentialCtrl,
              label: 'Email or username',
              keyboardType: TextInputType.text,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 11),
            AuthField(
              controller: _passwordCtrl,
              label: 'Password',
              obscure: true,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () => context.push('/forgot-password'),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.indigo),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            AuthPrimaryButton(
              label: 'Log in',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 18),
            SocialSignInButtons(
              onError: (msg) => setState(() => _error = msg),
              onSignedIn: _onSignedIn,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Center(
                child: GestureDetector(
                  onTap: () => context.go('/register'),
                  child: Text.rich(
                    TextSpan(
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.muted),
                      children: [
                        const TextSpan(text: 'New here? '),
                        TextSpan(text: 'Create account', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.indigo)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
