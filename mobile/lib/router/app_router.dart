import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/combos/generate_combo_screen.dart';
import '../features/combos/public_combos_screen.dart';
import '../features/combos/my_combos_screen.dart';
import '../features/combos/combo_detail_screen.dart';
import '../features/preferences/preferences_screen.dart';
import '../features/tricks/submit_trick_screen.dart';
import '../features/tricks/tricks_screen.dart';
import '../features/admin/admin_submissions_screen.dart';
import '../features/combos/build_combo_screen.dart';
import '../widgets/main_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/public',
  redirect: (context, state) {
    final authed = AuthService.instance.isAuthenticated;
    final protectedRoutes = ['/generate', '/mine', '/preferences', '/tricks/submit', '/admin', '/combos/build'];
    final authRoutes = ['/login', '/register'];

    if (!authed && protectedRoutes.any((r) => state.matchedLocation.startsWith(r))) {
      return '/login';
    }
    if (authed && authRoutes.contains(state.matchedLocation)) {
      return '/generate';
    }
    // Redirect non-admins away from admin routes
    if (state.matchedLocation.startsWith('/admin') && !AuthService.instance.isAdmin) {
      return '/generate';
    }
    return null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/public', builder: (_, __) => const PublicCombosScreen()),
        GoRoute(path: '/tricks', builder: (_, __) => const TricksScreen()),
        GoRoute(path: '/generate', builder: (_, __) => const GenerateComboScreen()),
        GoRoute(path: '/combos/build', builder: (_, __) => const BuildComboScreen()),
        GoRoute(path: '/mine', builder: (_, __) => const MyCombosScreen()),
        GoRoute(path: '/preferences', builder: (_, __) => const PreferencesScreen()),
        GoRoute(path: '/tricks/submit', builder: (_, __) => const SubmitTrickScreen()),
        GoRoute(path: '/admin/submissions', builder: (_, __) => const AdminSubmissionsScreen()),
        GoRoute(
          path: '/combos/:id',
          builder: (_, state) => ComboDetailScreen(id: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
  ],
);
