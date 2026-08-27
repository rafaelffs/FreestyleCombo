import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api/api_client.dart';
import '../core/auth/auth_service.dart';
import '../features/combos/unsaved_combo_guard.dart';
import '../theme/app_colors.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _pendingCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchCount();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchCount());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCount() async {
    if (!AuthService.instance.isAdmin) return;
    try {
      final count = await ApiClient.instance.getPendingApprovalsCount();
      if (mounted) setState(() => _pendingCount = count);
    } catch (_) {}
  }

  // The bottom nav navigates via context.go(), which replaces the current
  // location outright — it doesn't consult the Build-combo screen's own
  // back-button confirmation. Guard it here instead, so switching tabs while
  // an unsaved combo is in progress doesn't silently discard it.
  Future<void> _navigateGuarded(BuildContext context, String path) async {
    if (UnsavedComboGuard.hasUnsavedWork) {
      final count = UnsavedComboGuard.pendingTrickCount;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Discard combo?',
              style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
          content: Text(
            'You have $count trick${count == 1 ? '' : 's'} in an unsaved combo. Leaving now will discard it.',
            style: GoogleFonts.plusJakartaSans(color: AppColors.ink2, fontSize: 14),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      UnsavedComboGuard.clear();
    }
    if (context.mounted) context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final authed = AuthService.instance.isAuthenticated;
    final admin = AuthService.instance.isAdmin;
    final location = GoRouterState.of(context).matchedLocation;

    String selected = 'combos';
    if (location.startsWith('/tricks')) {
      selected = 'tricks';
    } else if (location.startsWith('/combos/create')) {
      selected = 'generate';
    } else if (authed && location.startsWith('/preferences')) {
      selected = 'presets';
    } else if (authed && location.startsWith('/account')) {
      selected = 'profile';
    } else if (admin && location.startsWith('/admin')) {
      selected = 'admin';
    } else if (!authed && (location == '/login' || location == '/register')) {
      selected = 'login';
    }

    // A single row of equal-width tabs — Generate sits inline (styled with a
    // gradient icon chip for emphasis) instead of overflowing above the bar,
    // so nothing gets clipped and every tab lines up evenly regardless of
    // auth state.
    final tabs = <Widget>[
      _NavItem(
        icon: Icons.sports_soccer_outlined,
        label: 'Combos',
        selected: selected == 'combos',
        onTap: () => _navigateGuarded(context, '/combos'),
      ),
      _NavItem(
        icon: Icons.list_alt_outlined,
        label: 'Tricks',
        selected: selected == 'tricks',
        onTap: () => _navigateGuarded(context, '/tricks'),
      ),
      _NavItem(
        icon: Icons.bolt,
        label: 'Generate',
        selected: selected == 'generate',
        gradient: true,
        // Routed through the same guard as the other tabs: warns before
        // discarding an in-progress combo, and uses go() (not push()) so
        // re-tapping Generate while already on it resets to a fresh screen
        // instead of stacking a second, empty instance on top.
        onTap: () => _navigateGuarded(context, '/combos/create'),
      ),
      // Always shown, even signed out — router redirect sends an
      // unauthenticated tap on Presets/Profile to /login.
      _NavItem(
        icon: Icons.tune,
        label: 'Presets',
        selected: selected == 'presets',
        onTap: () => _navigateGuarded(context, '/preferences'),
      ),
      _NavItem(
        icon: Icons.person_outline,
        label: 'Profile',
        selected: selected == 'profile',
        onTap: () => _navigateGuarded(context, '/account'),
      ),
      if (authed && admin)
        _NavItem(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Admin',
          selected: selected == 'admin',
          badgeCount: _pendingCount,
          onTap: () => _navigateGuarded(context, '/admin/approvals'),
        ),
    ];

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                    spreadRadius: -14,
                  ),
                ],
              ),
              child: Row(children: tabs),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int? badgeCount;
  final bool gradient;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.indigo : AppColors.faint;

    Widget iconWidget = gradient
        ? Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: AppColors.grad,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 17, color: Colors.white),
          )
        : Icon(icon, size: 23, color: color);

    if (badgeCount != null && badgeCount! > 0) {
      iconWidget = Badge(
        label: Text('$badgeCount'),
        backgroundColor: AppColors.red,
        child: iconWidget,
      );
    }

    return Expanded(
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
