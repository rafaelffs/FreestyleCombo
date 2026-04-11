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

    // Authenticated:   Combos(0), Tricks(1), Settings(2), Admin(3, admin)
    // Unauthenticated: Combos(0), Tricks(1), Login(2)
    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.sports_soccer_outlined), label: 'Combos'),
      const NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Tricks'),
      if (authed)
        const NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
      if (!authed)
        const NavigationDestination(icon: Icon(Icons.login), label: 'Login'),
      if (admin)
        const NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), label: 'Admin'),
    ];

    int selectedIndex = 0;
    if (authed) {
      if (location.startsWith('/tricks')) selectedIndex = 1;
      if (location.startsWith('/preferences')) selectedIndex = 2;
      if (admin && location.startsWith('/admin')) selectedIndex = 3;
    } else {
      if (location.startsWith('/tricks')) selectedIndex = 1;
      if (location == '/login' || location == '/register') selectedIndex = 2;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          if (!authed) {
            // Unauthenticated: Combos(0), Tricks(1), Login(2)
            switch (i) {
              case 0: context.go('/combos');
              case 1: context.go('/tricks');
              case 2: context.go('/login');
            }
            return;
          }
          // Authenticated: Combos(0), Tricks(1), Settings(2), Admin(3)
          switch (i) {
            case 0: context.go('/combos');
            case 1: context.go('/tricks');
            case 2: context.go('/preferences');
            case 3: if (admin) context.go('/admin/approvals');
          }
        },
        destinations: destinations,
      ),
    );
  }
}
