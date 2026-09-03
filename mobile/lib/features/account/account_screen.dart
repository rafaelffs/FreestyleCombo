import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user.dart';
import '../../core/prefs/foot_orientation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/display_options.dart' show SegmentButton;

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  ProfileDto? _profile;
  bool _loading = true;
  String? _error;

  int _comboCount = 0;
  int _doneCount = 0;
  double? _avgRating;
  bool _advancedOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await ApiClient.instance.getProfile();
      final combos = await ApiClient.instance.getMyCombos();
      var done = 0;
      var ratingSum = 0.0;
      var ratingWeight = 0;
      for (final c in combos.items) {
        if (c.isCompleted) done++;
        if (c.totalRatings > 0) {
          ratingSum += c.averageRating * c.totalRatings;
          ratingWeight += c.totalRatings;
        }
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _comboCount = combos.totalCount;
        _doneCount = done;
        _avgRating = ratingWeight > 0 ? ratingSum / ratingWeight : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _EditProfileScreen(profile: _profile!)),
    );
    if (updated == true) _load();
  }

  void _logout() {
    AuthService.instance.clear();
    context.go('/combos');
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete account?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: Text(
          'This permanently deletes your account, combos, preferences and ratings. This cannot be undone.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.ink2, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.deleteAccount();
      AuthService.instance.clear();
      if (mounted) context.go('/combos');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.indigo))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _ProfileHeader(
                        profile: _profile!,
                        comboCount: _comboCount,
                        doneCount: _doneCount,
                        avgRating: _avgRating,
                        onDoneTap: () => context.push('/combos', extra: true),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Text(
                            'PREFERENCES',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.faint),
                          ),
                          const SizedBox(height: 12),
                          _StrongFootRow(onChanged: () => setState(() {})),
                          const SizedBox(height: 24),
                          Text(
                            'ACCOUNT',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.faint),
                          ),
                          const SizedBox(height: 12),
                          _RowLink(
                            icon: Icons.person_outline,
                            label: 'Edit profile & password',
                            onTap: _openEditProfile,
                          ),
                          const SizedBox(height: 10),
                          _RowLink(
                            icon: Icons.layers_outlined,
                            label: 'My combos',
                            onTap: () => context.go('/combos'),
                          ),
                          const SizedBox(height: 10),
                          _RowLink(
                            icon: Icons.logout,
                            label: 'Log out',
                            showChevron: false,
                            onTap: _logout,
                          ),
                          const SizedBox(height: 10),
                          _RowLink(
                            icon: Icons.tune,
                            label: 'Advanced settings',
                            showChevron: false,
                            trailingIcon: _advancedOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            onTap: () => setState(() => _advancedOpen = !_advancedOpen),
                          ),
                          if (_advancedOpen) ...[
                            const SizedBox(height: 10),
                            _RowLink(
                              icon: Icons.delete_outline,
                              label: 'Delete account',
                              showChevron: false,
                              destructive: true,
                              onTap: _confirmDeleteAccount,
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final ProfileDto profile;
  final int comboCount;
  final int doneCount;
  final double? avgRating;
  final VoidCallback onDoneTap;

  const _ProfileHeader({
    required this.profile,
    required this.comboCount,
    required this.doneCount,
    required this.avgRating,
    required this.onDoneTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = profile.userName.isNotEmpty ? profile.userName.substring(0, 1).toUpperCase() : 'U';
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.grad),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -50,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lime.withValues(alpha: 0.16)),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            initial,
                            style: GoogleFonts.plusJakartaSans(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.userName,
                                style: GoogleFonts.plusJakartaSans(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Freestyler',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _StatTile(value: '$comboCount', label: 'Combos')),
                        const SizedBox(width: 10),
                        Expanded(child: _StatTile(value: '$doneCount', label: 'Done', onTap: onDoneTap)),
                        const SizedBox(width: 10),
                        Expanded(child: _StatTile(value: avgRating != null ? avgRating!.toStringAsFixed(1) : '—', label: 'Avg ★')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  const _StatTile({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}

class _RowLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showChevron;
  final bool destructive;
  final IconData? trailingIcon;

  const _RowLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showChevron = true,
    this.destructive = false,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? AppColors.red : AppColors.indigo;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: destructive ? AppColors.redBg : AppColors.chipBg, borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 18, color: tint),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: destructive ? tint : AppColors.ink)),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, size: 20, color: AppColors.faint)
              else if (showChevron)
                const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrongFootRow extends StatelessWidget {
  final VoidCallback onChanged;

  const _StrongFootRow({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isRight = FootOrientation.strongFootIsRight;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.accessibility_new, size: 18, color: AppColors.indigo),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'My strong foot',
              style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
          SegmentButton(
            label: 'Left',
            active: !isRight,
            onTap: () async {
              await FootOrientation.setStrongFootIsRight(false);
              onChanged();
            },
          ),
          const SizedBox(width: 6),
          SegmentButton(
            label: 'Right',
            active: isRight,
            onTap: () async {
              await FootOrientation.setStrongFootIsRight(true);
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

// ── Edit profile & password sub-screen ──────────────────────────────────────────

class _EditProfileScreen extends StatefulWidget {
  final ProfileDto profile;
  const _EditProfileScreen({required this.profile});

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  late ProfileDto _profile = widget.profile;

  final _userNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _profileSaving = false;
  String? _profileError;
  String? _profileSuccess;

  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _pwSaving = false;
  String? _pwError;
  String? _pwSuccess;

  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _userNameCtrl.text = _profile.userName;
    _emailCtrl.text = _profile.email;
  }

  @override
  void dispose() {
    _userNameCtrl.dispose();
    _emailCtrl.dispose();
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final newUserName = _userNameCtrl.text.trim();
    final newEmail = _emailCtrl.text.trim();
    if (newUserName.isEmpty && newEmail.isEmpty) return;

    setState(() { _profileSaving = true; _profileError = null; _profileSuccess = null; });
    try {
      final updated = await ApiClient.instance.updateProfile(
        userName: newUserName.isNotEmpty && newUserName != _profile.userName ? newUserName : null,
        email: newEmail.isNotEmpty && newEmail != _profile.email ? newEmail : null,
      );
      if (updated.userName != _profile.userName) {
        await AuthService.instance.setUserName(updated.userName);
      }
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _profileSuccess = 'Profile updated.';
        _profileSaving = false;
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileError = e.toString().replaceFirst('Exception: ', '');
        _profileSaving = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPwCtrl.text;
    final newPw = _newPwCtrl.text;
    final confirm = _confirmPwCtrl.text;

    if (newPw != confirm) {
      setState(() => _pwError = 'New passwords do not match.');
      return;
    }
    if (newPw.length < 6) {
      setState(() => _pwError = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _pwSaving = true; _pwError = null; _pwSuccess = null; });
    try {
      await ApiClient.instance.changePassword(current, newPw);
      if (!mounted) return;
      setState(() {
        _pwSuccess = 'Password changed.';
        _pwSaving = false;
        _currentPwCtrl.clear();
        _newPwCtrl.clear();
        _confirmPwCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pwError = e.toString().replaceFirst('Exception: ', '');
        _pwSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Edit profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context, _changed),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _SectionCard(
              title: 'Profile',
              children: [
                _FormField(label: 'Username', controller: _userNameCtrl),
                const SizedBox(height: 12),
                _FormField(label: 'Email', controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                if (_profileError != null) ...[
                  const SizedBox(height: 8),
                  Text(_profileError!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                ],
                if (_profileSuccess != null) ...[
                  const SizedBox(height: 8),
                  Text(_profileSuccess!, style: const TextStyle(color: AppColors.green, fontSize: 12)),
                ],
                const SizedBox(height: 14),
                _SaveButton(loading: _profileSaving, label: 'Save changes', onPressed: _saveProfile),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Change password',
              children: [
                _FormField(label: 'Current password', controller: _currentPwCtrl, obscure: true),
                const SizedBox(height: 12),
                _FormField(label: 'New password', controller: _newPwCtrl, obscure: true),
                const SizedBox(height: 12),
                _FormField(label: 'Confirm new password', controller: _confirmPwCtrl, obscure: true),
                if (_pwError != null) ...[
                  const SizedBox(height: 8),
                  Text(_pwError!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                ],
                if (_pwSuccess != null) ...[
                  const SizedBox(height: 8),
                  Text(_pwSuccess!, style: const TextStyle(color: AppColors.green, fontSize: 12)),
                ],
                const SizedBox(height: 14),
                _SaveButton(loading: _pwSaving, label: 'Change password', onPressed: _changePassword),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;

  const _FormField({required this.label, required this.controller, this.obscure = false, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.chipBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onPressed;
  const _SaveButton({required this.loading, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.indigo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
