import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/combos/combos_screen.dart';
import '../features/combos/create_combo_screen.dart';
import '../features/combos/combo_detail_screen.dart';
import '../features/preferences/preferences_screen.dart';
import '../features/tricks/tricks_screen.dart';
import '../features/admin/admin_submissions_screen.dart';
import '../widgets/main_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/combos',
  redirect: (context, state) {
    final authed = AuthService.instance.isAuthenticated;
    final protectedRoutes = ['/combos/create', '/preferences', '/admin'];
    final authRoutes = ['/login', '/register'];

    if (!authed && protectedRoutes.any((r) => state.matchedLocation.startsWith(r))) {
      return '/login';
    }
    if (authed && authRoutes.contains(state.matchedLocation)) {
      return '/combos';
    }
    // Redirect non-admins away from admin routes
    if (state.matchedLocation.startsWith('/admin') && !AuthService.instance.isAdmin) {
      return '/combos';
    }
    return null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/combos', builder: (_, __) => const CombosScreen()),
        GoRoute(path: '/tricks', builder: (_, __) => const TricksScreen()),
        GoRoute(path: '/combos/create', builder: (_, __) => const CreateComboScreen()),
        GoRoute(path: '/preferences', builder: (_, __) => const PreferencesScreen()),
        GoRoute(path: '/admin/approvals', builder: (_, __) => const AdminSubmissionsScreen()),
        GoRoute(path: '/admin/submissions', redirect: (_, __) => '/admin/approvals'),
        GoRoute(path: '/admin/combo-reviews', redirect: (_, __) => '/admin/approvals'),
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
