import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'core/auth/auth_service.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';

// OAuth client IDs are not secret — they're meant to be embedded in the
// client app (unlike the client *secret*, which this app never uses: the
// backend verifies ID tokens against Google's public JWKS directly, no
// server-side code exchange). Android isn't configured yet — no
// google-services.json in mobile/android/app/ — so initialize() only
// passes a clientId on iOS for now.
const _googleIosClientId =
    '186715626569-olj62i0ps6am3c0en0g4i1983au1dmij.apps.googleusercontent.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.init();
  await GoogleSignIn.instance.initialize(
    clientId: Platform.isIOS ? _googleIosClientId : null,
  );
  runApp(const FreestyleComboApp());
}

class FreestyleComboApp extends StatelessWidget {
  const FreestyleComboApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return MaterialApp.router(
      title: 'FreestyleCombo',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.indigo,
          primary: AppColors.indigo,
          surface: AppColors.surface,
        ),
        textTheme: baseTextTheme.apply(
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.ink,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AppColors.ink,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
    );
  }
}
