import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';
import '../../theme/app_colors.dart';
import 'auth_chrome.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _userNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _userNameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Register (no token returned), then login to get token
      await ApiClient.instance.register(
        _emailCtrl.text.trim(),
        _userNameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      final login = await ApiClient.instance
          .login(_emailCtrl.text.trim(), _passwordCtrl.text);
      await AuthService.instance.setCredentials(login.token, login.userId);
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
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      headline: 'Create your\nfree ',
      headlineAccent: 'account.',
      subtitle: 'Save your combos, rate others, and track your progress as you level up.',
      sheet: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              controller: _emailCtrl,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 11),
            AuthField(
              controller: _userNameCtrl,
              label: 'Username',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 3) return 'At least 3 characters';
                return null;
              },
            ),
            const SizedBox(height: 11),
            AuthField(
              controller: _passwordCtrl,
              label: 'Password',
              obscure: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            AuthPrimaryButton(
              label: 'Create account',
              loading: _loading,
              onPressed: _submit,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Center(
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text.rich(
                    TextSpan(
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.muted),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(text: 'Sign in', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.indigo)),
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
