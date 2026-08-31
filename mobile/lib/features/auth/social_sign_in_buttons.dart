import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../theme/app_colors.dart';

/// Google + (iOS-only) Apple sign-in buttons, shared by the login and
/// register screens — both actions hit the same backend endpoints, which
/// transparently create-or-sign-in an account, so there's no separate
/// "register with Google" flow to build.
class SocialSignInButtons extends StatefulWidget {
  final ValueChanged<String> onError;
  final VoidCallback onSignedIn;

  const SocialSignInButtons({
    super.key,
    required this.onError,
    required this.onSignedIn,
  });

  @override
  State<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends State<SocialSignInButtons> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      widget.onError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() => _run(() async {
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw Exception('Google did not return a sign-in token.');
        }
        final result = await ApiClient.instance.signInWithGoogle(idToken);
        await AuthService.instance.setCredentials(result.token, result.userId);
        widget.onSignedIn();
      });

  Future<void> _signInWithApple() => _run(() async {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        final idToken = credential.identityToken;
        if (idToken == null) {
          throw Exception('Apple did not return a sign-in token.');
        }
        final result = await ApiClient.instance.signInWithApple(idToken);
        await AuthService.instance.setCredentials(result.token, result.userId);
        widget.onSignedIn();
      });

  @override
  Widget build(BuildContext context) {
    final showApple = Platform.isIOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('or', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted)),
            ),
            const Expanded(child: Divider(color: AppColors.line)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _signInWithGoogle,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.g_mobiledata, size: 26, color: AppColors.ink),
            label: Text('Continue with Google',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
        ),
        if (showApple) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: SignInWithAppleButton(
              onPressed: _busy ? () {} : _signInWithApple,
              style: SignInWithAppleButtonStyle.black,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ],
    );
  }
}
