import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authed = AuthService.instance.isAuthenticated;
    final location = GoRouterState.of(context).matchedLocation;

    int selectedIndex = 0;
    if (location.startsWith('/generate')) selectedIndex = 1;
    if (location.startsWith('/mine')) selectedIndex = 2;
    if (location.startsWith('/preferences')) selectedIndex = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/public');
            case 1:
              if (authed) {
                context.go('/generate');
              } else {
                context.go('/login');
              }
            case 2:
              if (authed) {
                context.go('/mine');
              } else {
                context.go('/login');
              }
            case 3:
              if (authed) {
                context.go('/preferences');
              } else {
                context.go('/login');
              }
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.public), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Generate'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'Mine'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}
