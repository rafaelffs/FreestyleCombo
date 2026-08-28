import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../theme/app_colors.dart';
import 'auth_chrome.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { request, reset }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  _Step _step = _Step.request;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.forgotPassword(_emailCtrl.text.trim());
      if (mounted) setState(() => _step = _Step.reset);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.resetPassword(
        _emailCtrl.text.trim(),
        _codeCtrl.text.trim(),
        _newPasswordCtrl.text,
      );
      if (mounted) context.go('/login');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      headline: 'Reset your\n',
      headlineAccent: 'password.',
      subtitle: _step == _Step.request
          ? "Enter your email and we'll send you a reset code."
          : 'Enter the code we sent you and choose a new password.',
      sheet: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _step == _Step.request
              ? [
                  AuthField(
                    controller: _emailCtrl,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 18),
                  AuthPrimaryButton(
                    label: 'Send code',
                    loading: _loading,
                    onPressed: _requestCode,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Center(
                      child: GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          'Back to sign in',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.indigo),
                        ),
                      ),
                    ),
                  ),
                ]
              : [
                  Text(
                    'We sent a 6-digit code to ${_emailCtrl.text.trim()}.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  AuthField(
                    controller: _codeCtrl,
                    label: 'Reset code',
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.length != 6 ? '6-digit code' : null,
                  ),
                  const SizedBox(height: 11),
                  AuthField(
                    controller: _newPasswordCtrl,
                    label: 'New password',
                    obscure: true,
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 11),
                  AuthField(
                    controller: _confirmPasswordCtrl,
                    label: 'Confirm new password',
                    obscure: true,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 18),
                  AuthPrimaryButton(
                    label: 'Reset password',
                    loading: _loading,
                    onPressed: _resetPassword,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Center(
                      child: GestureDetector(
                        onTap: () => setState(() => _step = _Step.request),
                        child: Text(
                          "Didn't get it? Send a new code",
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.indigo),
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
