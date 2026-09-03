import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'confirm_sheet.dart';

/// Small icon-button replacement for a full-width toggle row — used where
/// vertical space matters (e.g. the build/edit combo screens' action panel,
/// which sits above a scrollable trick list). Tapping it always explains
/// what the setting does via a confirm sheet before applying the change,
/// rather than toggling instantly, since the icon alone doesn't carry much
/// meaning at a glance.
class SettingIconButton extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool active;
  final Color activeColor;
  final String title;
  final String description;
  final String confirmLabel;
  final ValueChanged<bool> onChanged;

  const SettingIconButton({
    super.key,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.active,
    required this.activeColor,
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.onChanged,
  });

  Future<void> _handleTap(BuildContext context) async {
    final confirmed = await showConfirmSheet(
      context,
      title: title,
      description: description,
      confirmLabel: confirmLabel,
    );
    if (confirmed) onChanged(!active);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? activeColor.withValues(alpha: 0.12) : AppColors.chipBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: active ? activeColor.withValues(alpha: 0.35) : AppColors.line2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => _handleTap(context),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(active ? activeIcon : inactiveIcon, size: 20, color: active ? activeColor : AppColors.muted),
        ),
      ),
    );
  }
}
