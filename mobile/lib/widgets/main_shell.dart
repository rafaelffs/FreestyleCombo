import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authed = AuthService.instance.isAuthenticated;
    final admin = AuthService.instance.isAdmin;
    final location = GoRouterState.of(context).matchedLocation;

    // Build destinations dynamically
    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.public), label: 'Explore'),
      const NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Generate'),
      const NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'Mine'),
      const NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
      const NavigationDestination(icon: Icon(Icons.upload_outlined), label: 'Submit'),
      if (admin)
        const NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), label: 'Admin'),
    ];

    int selectedIndex = 0;
    if (location.startsWith('/generate')) selectedIndex = 1;
    if (location.startsWith('/mine')) selectedIndex = 2;
    if (location.startsWith('/preferences')) selectedIndex = 3;
    if (location.startsWith('/tricks/submit')) selectedIndex = 4;
    if (admin && location.startsWith('/admin')) selectedIndex = 5;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/public');
            case 1:
              authed ? context.go('/generate') : context.go('/login');
            case 2:
              authed ? context.go('/mine') : context.go('/login');
            case 3:
              authed ? context.go('/preferences') : context.go('/login');
            case 4:
              authed ? context.go('/tricks/submit') : context.go('/login');
            case 5:
              if (admin) context.go('/admin/submissions');
          }
        },
        destinations: destinations,
      ),
    );
  }
}
